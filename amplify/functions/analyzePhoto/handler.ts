import {
	RekognitionClient,
	IndexFacesCommand,
	DetectTextCommand,
	CreateCollectionCommand,
	ListCollectionsCommand,
	SearchFacesCommand,
} from '@aws-sdk/client-rekognition';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
	DynamoDBDocumentClient,
	UpdateCommand,
	PutCommand,
	ScanCommand,
	GetCommand,
} from '@aws-sdk/lib-dynamodb';
import { v4 as uuidv4 } from 'uuid';

const rekognition = new RekognitionClient();
const s3 = new S3Client();
const ddb = new DynamoDBClient({});
const ddbDoc = DynamoDBDocumentClient.from(ddb);

const COLLECTION_ID =
	process.env.REKOGNITION_COLLECTION_ID || 'photosense-faces';
const PHOTO_TABLE_NAME = process.env.PHOTO_TABLE_NAME;
const PERSON_TABLE_NAME = process.env.PERSON_TABLE_NAME;
const PHOTOPERSON_TABLE_NAME = process.env.PHOTOPERSON_TABLE_NAME;

interface AnalyzePhotoResult {
	faceIds: string[];
	facesCount: number;
	detectedText: string[];
	detectedFaces: any[];
}

export const handler = async (event: any): Promise<void> => {
	console.log('Received S3 event:', JSON.stringify(event, null, 2));

	for (const record of event.Records) {
		const s3Key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
		const bucketName = record.s3.bucket.name;

		console.log(`Analyzing photo: ${s3Key} in bucket: ${bucketName}`);

		try {
			await ensureCollection();

			// Extract Photo ID
			const fileName = s3Key.split('/').pop();
			const photoId = fileName?.split('.')[0];

			let owner: string | undefined;

			// Extract owner from S3 key path: photos/{identityId}/{uuid}.ext
			// The identityId from Cognito is the owner identifier used by Amplify
			const s3Parts = s3Key.split('/');
			if (s3Parts.length >= 3 && s3Parts[0] === 'photos') {
				const identityId = s3Parts[1];
				// Amplify Gen 2 owner format is just the identity pool sub
				owner = identityId;
				console.log(`Owner extracted from S3 key: ${owner}`);
			}

			// Wait briefly for Photo record to be created by the frontend
			let photoExists = false;
			if (PHOTO_TABLE_NAME && photoId) {
				for (let attempt = 0; attempt < 3; attempt++) {
					try {
						const photoRes = await ddbDoc.send(
							new GetCommand({
								TableName: PHOTO_TABLE_NAME,
								Key: { id: photoId },
							}),
						);
						if (photoRes.Item) {
							photoExists = true;
							// Use the Photo record's owner if available (more reliable)
							if (photoRes.Item.owner) {
								owner = photoRes.Item.owner;
								console.log(`Owner from Photo record: ${owner}`);
							}
							break;
						}
					} catch (e) {
						console.warn(
							`Attempt ${attempt + 1}: Could not fetch photo ${photoId}`,
							e,
						);
					}
					// Wait 1 second before retrying
					await new Promise((resolve) => setTimeout(resolve, 1000));
				}
				if (!photoExists) {
					console.log(
						`Photo record ${photoId} not found after retries, using owner from S3 key`,
					);
				}
			}

			// Run Analysis
			const [faceResult, detectedText] = await Promise.all([
				indexFaces(bucketName, s3Key),
				detectText(bucketName, s3Key),
			]);

			// Clustering Logic (Streaming)
			console.log(
				`Clustering check: photoId=${photoId}, PERSON_TABLE=${PERSON_TABLE_NAME}, PHOTOPERSON_TABLE=${PHOTOPERSON_TABLE_NAME}, facesDetected=${faceResult.detectedFaces.length}`,
			);
			if (
				photoId &&
				PERSON_TABLE_NAME &&
				PHOTOPERSON_TABLE_NAME &&
				faceResult.detectedFaces.length > 0
			) {
				console.log(
					`Clustering ${faceResult.detectedFaces.length} faces for photo ${photoId}`,
				);
				for (const face of faceResult.detectedFaces) {
					await processFace(
						face.faceId,
						photoId,
						s3Key,
						face.boundingBox,
						owner,
					);
				}
			} else {
				console.log(
					'Clustering SKIPPED - missing env vars or no faces detected',
				);
			}

			const result: AnalyzePhotoResult = {
				faceIds: faceResult.faceIds,
				facesCount: faceResult.facesCount,
				detectedFaces: faceResult.detectedFaces,
				detectedText,
			};

			console.log(`Analysis result for ${s3Key}:`, JSON.stringify(result));

			// Update DynamoDB if table name is available
			if (PHOTO_TABLE_NAME && photoId) {
				console.log(
					`Updating Photo record ${photoId} in table ${PHOTO_TABLE_NAME}`,
				);
				await ddbDoc.send(
					new UpdateCommand({
						TableName: PHOTO_TABLE_NAME,
						Key: { id: photoId },
						UpdateExpression:
							'SET facesCount = :fc, detectedText = :dt, faceIds = :fi, detectedFaces = :df, analyzedAt = :at',
						ExpressionAttributeValues: {
							':fc': result.facesCount,
							':dt': result.detectedText,
							':fi': result.faceIds,
							':df': result.detectedFaces,
							':at': new Date().toISOString(),
						},
					}),
				);
				console.log(`Updated Photo record ${photoId}`);
			}
		} catch (error) {
			console.error(`Error processing ${s3Key}:`, error);
		}
	}
};

async function processFace(
	faceId: string,
	photoId: string,
	photoS3Key: string,
	boundingBox: any,
	owner?: string,
) {
	try {
		// 1. Search for matches in Rekognition
		const searchRes = await rekognition.send(
			new SearchFacesCommand({
				CollectionId: COLLECTION_ID,
				FaceId: faceId,
				FaceMatchThreshold: 90,
				MaxFaces: 1,
			}),
		);

		let personId: string | null = null;
		let matchedFaceId: string | null = null;

		if (searchRes.FaceMatches && searchRes.FaceMatches.length > 0) {
			matchedFaceId = searchRes.FaceMatches[0].Face?.FaceId || null;
			console.log(`Face ${faceId} matches ${matchedFaceId}`);
		}

		// 2. Find Person in DB
		if (matchedFaceId) {
			// Inefficient Scan for MVP (Use GSI in production)
			const scanRes = await ddbDoc.send(
				new ScanCommand({
					TableName: PERSON_TABLE_NAME,
					FilterExpression: 'contains(faceIds, :fid)',
					ExpressionAttributeValues: { ':fid': matchedFaceId },
				}),
			);

			if (scanRes.Items && scanRes.Items.length > 0) {
				const person = scanRes.Items[0];
				personId = person.id;
				console.log(`Match belongs to Person: ${person.name} (${personId})`);

				// Update Person with new faceId
				const currentFaceIds = person.faceIds || [];
				if (!currentFaceIds.includes(faceId)) {
					await ddbDoc.send(
						new UpdateCommand({
							TableName: PERSON_TABLE_NAME,
							Key: { id: personId },
							UpdateExpression: 'SET faceIds = list_append(faceIds, :fid)',
							ExpressionAttributeValues: { ':fid': [faceId] },
						}),
					);
				}
			}
		}

		// 3. If no person found, create new Unnamed Person
		if (!personId) {
			console.log(`No match found for ${faceId}, creating new Unnamed Person`);
			personId = uuidv4();
			const now = new Date().toISOString();

			const item: any = {
				id: personId,
				name: `Unknown Person`,
				isUnnamed: true,
				faceId: faceId, // Main face
				faceIds: [faceId],
				boundingBox: JSON.stringify(boundingBox),
				thumbnailS3Key: photoS3Key,
				createdAt: now,
				updatedAt: now,
			};
			if (owner) item.owner = owner;

			await ddbDoc.send(
				new PutCommand({
					TableName: PERSON_TABLE_NAME,
					Item: item,
				}),
			);
		}

		// 4. Link Photo to Person
		if (personId) {
			const linkId = uuidv4();
			const item: any = {
				id: linkId,
				photoId: photoId,
				personId: personId,
				createdAt: new Date().toISOString(),
				updatedAt: new Date().toISOString(),
			};
			if (owner) item.owner = owner;

			await ddbDoc.send(
				new PutCommand({
					TableName: PHOTOPERSON_TABLE_NAME,
					Item: item,
				}),
			);
		}
	} catch (e) {
		console.error(`Error processing face ${faceId}:`, e);
	}
}

async function ensureCollection(): Promise<void> {
	try {
		const { CollectionIds } = await rekognition.send(
			new ListCollectionsCommand({}),
		);

		if (!CollectionIds?.includes(COLLECTION_ID)) {
			await rekognition.send(
				new CreateCollectionCommand({ CollectionId: COLLECTION_ID }),
			);
			console.log(`Created Rekognition collection: ${COLLECTION_ID}`);
		}
	} catch (error) {
		console.error('Error ensuring collection:', error);
		throw error;
	}
}

async function indexFaces(
	bucketName: string,
	s3Key: string,
): Promise<{ faceIds: string[]; facesCount: number; detectedFaces: any[] }> {
	try {
		const response = await rekognition.send(
			new IndexFacesCommand({
				CollectionId: COLLECTION_ID,
				Image: {
					S3Object: {
						Bucket: bucketName,
						Name: s3Key,
					},
				},
				ExternalImageId: s3Key.replace(/[^a-zA-Z0-9_.\-:]/g, '_'),
				DetectionAttributes: ['DEFAULT'],
			}),
		);

		const faceIds: string[] = [];
		const detectedFaces: any[] = [];

		if (response.FaceRecords) {
			for (const record of response.FaceRecords) {
				if (record.Face?.FaceId) {
					faceIds.push(record.Face.FaceId);
					detectedFaces.push({
						faceId: record.Face.FaceId,
						boundingBox: record.Face.BoundingBox,
						confidence: record.Face.Confidence,
					});
				}
			}
		}

		return {
			faceIds,
			facesCount: faceIds.length,
			detectedFaces,
		};
	} catch (error) {
		console.error('Error indexing faces:', error);
		return { faceIds: [], facesCount: 0, detectedFaces: [] };
	}
}

async function detectText(
	bucketName: string,
	s3Key: string,
): Promise<string[]> {
	try {
		const response = await rekognition.send(
			new DetectTextCommand({
				Image: {
					S3Object: {
						Bucket: bucketName,
						Name: s3Key,
					},
				},
			}),
		);

		// Only return LINE-type detections (not individual WORDs)
		const textLines =
			response.TextDetections?.filter(
				(detection) =>
					detection.Type === 'LINE' && (detection.Confidence || 0) > 80,
			).map((detection) => detection.DetectedText || '') || [];

		return textLines;
	} catch (error) {
		console.error('Error detecting text:', error);
		return [];
	}
}
