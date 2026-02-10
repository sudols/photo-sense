/// <reference types="node" />

import {
	RekognitionClient,
	IndexFacesCommand,
	DetectTextCommand,
	CreateCollectionCommand,
	ListCollectionsCommand,
} from '@aws-sdk/client-rekognition';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

const rekognition = new RekognitionClient();
const s3 = new S3Client();

const COLLECTION_ID =
	process.env.REKOGNITION_COLLECTION_ID || 'photosense-faces';

interface AnalyzePhotoEvent {
	arguments: {
		s3Key: string;
		bucketName: string;
	};
}

interface AnalyzePhotoResult {
	faceIds: string[];
	facesCount: number;
	detectedText: string[];
}

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
): Promise<{ faceIds: string[]; facesCount: number }> {
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

		const faceIds =
			response.FaceRecords?.map((record) => record.Face?.FaceId || '').filter(
				(id) => id !== '',
			) || [];

		return {
			faceIds,
			facesCount: faceIds.length,
		};
	} catch (error) {
		console.error('Error indexing faces:', error);
		return { faceIds: [], facesCount: 0 };
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

/**
 * Lambda handler: analyzes a photo in S3 for faces and text.
 */
export const handler = async (
	event: AnalyzePhotoEvent,
): Promise<AnalyzePhotoResult> => {
	const { s3Key, bucketName } = event.arguments;

	console.log(`Analyzing photo: ${s3Key} in bucket: ${bucketName}`);

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
		detectedText,
	};

	console.log(`Analysis result:`, JSON.stringify(result));

	return result;
};
