/// <reference types="node" />

import {
	RekognitionClient,
	IndexFacesCommand,
	DetectTextCommand,
	CreateCollectionCommand,
	ListCollectionsCommand,
} from '@aws-sdk/client-rekognition';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const rekognition = new RekognitionClient();
const s3 = new S3Client();
const ddb = new DynamoDBClient({});
const ddbDoc = DynamoDBDocumentClient.from(ddb);

const COLLECTION_ID =
	process.env.REKOGNITION_COLLECTION_ID || 'photosense-faces';
const PHOTO_TABLE_NAME = process.env.PHOTO_TABLE_NAME;

interface AnalyzePhotoEvent {
	// ... existing interface ...
}

interface AnalyzePhotoResult {
	faceIds: string[];
	facesCount: number;
	detectedText: string[];
	detectedFaces: any[];
}

// ... helper functions ...

/**
 * Lambda handler: analyzes a photo in S3 for faces and text.
 * Triggered by S3 ObjectCreated event.
 */
export const handler = async (event: any): Promise<void> => {
	console.log('Received S3 event:', JSON.stringify(event, null, 2));

	for (const record of event.Records) {
		const s3Key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
		const bucketName = record.s3.bucket.name;

		console.log(`Analyzing photo: ${s3Key} in bucket: ${bucketName}`);

		try {
			// Ensure face collection exists
			await ensureCollection();

			// Run face indexing and text detection in parallel
			const [faceResult, detectedText] = await Promise.all([
				indexFaces(bucketName, s3Key),
				detectText(bucketName, s3Key),
			]);

			const result: AnalyzePhotoResult = {
				faceIds: faceResult.faceIds,
				facesCount: faceResult.facesCount,
				detectedFaces: faceResult.detectedFaces,
				detectedText,
			};

			console.log(`Analysis result for ${s3Key}:`, JSON.stringify(result));

			// Update DynamoDB if table name is available
			if (PHOTO_TABLE_NAME) {
				// Extract ID from s3Key: photos/identityId/uuid.ext -> uuid
				const fileName = s3Key.split('/').pop();
				const photoId = fileName?.split('.')[0];

				if (photoId) {
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
				} else {
					console.warn('Could not extract photo ID from S3 key:', s3Key);
				}
			} else {
				console.warn('PHOTO_TABLE_NAME not set, skipping DynamoDB update');
			}
		} catch (error) {
			console.error(`Error processing ${s3Key}:`, error);
		}
	}
};

/**
 * Ensures the Rekognition face collection exists, creating it if needed.
 */
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

/**
 * Indexes faces in the image into the Rekognition collection.
 */
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

/**
 * Detects text in the image using Rekognition OCR.
 */
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
