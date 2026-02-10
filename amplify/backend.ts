import { defineBackend } from '@aws-amplify/backend';
import { PolicyStatement, Effect } from 'aws-cdk-lib/aws-iam';
import { auth } from './auth/resource';
import { data } from './data/resource';
import { storage } from './storage/resource';
import { analyzePhoto } from './functions/analyzePhoto/resource';

const backend = defineBackend({
	auth,
	data,
	storage,
	analyzePhoto,
});

// Grant the Lambda function permissions to use Rekognition
const analyzePhotoLambda = backend.analyzePhoto.resources.lambda;

analyzePhotoLambda.addToRolePolicy(
	new PolicyStatement({
		effect: Effect.ALLOW,
		actions: [
			'rekognition:IndexFaces',
			'rekognition:SearchFacesByImage',
			'rekognition:DetectText',
			'rekognition:CreateCollection',
			'rekognition:ListCollections',
		],
		resources: ['*'],
	}),
);

// Grant Lambda read access to the S3 storage bucket
const s3Bucket = backend.storage.resources.bucket;
s3Bucket.grantRead(analyzePhotoLambda);

// Pass the bucket name to the Lambda as an environment variable
backend.analyzePhoto.addEnvironment('PHOTO_BUCKET_NAME', s3Bucket.bucketName);
