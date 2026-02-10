import { defineFunction } from '@aws-amplify/backend';

export const analyzePhoto = defineFunction({
	name: 'analyzePhoto',
	entry: './handler.ts',
	timeoutSeconds: 60,
	memoryMB: 512,
	environment: {
		REKOGNITION_COLLECTION_ID: 'photosense-faces',
	},
});
