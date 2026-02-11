import { defineBackend } from '@aws-amplify/backend';
import { PolicyStatement, Effect } from 'aws-cdk-lib/aws-iam';
import { EventType } from 'aws-cdk-lib/aws-s3';
import { LambdaDestination } from 'aws-cdk-lib/aws-s3-notifications';
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

// Grant permissions for analyze-photo
const analyzePhotoLambda = backend.analyzePhoto.resources.lambda;

analyzePhotoLambda.addToRolePolicy(
	new PolicyStatement({
		effect: Effect.ALLOW,
		actions: [
			'rekognition:IndexFaces',
			'rekognition:SearchFaces',
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

// Grant Lambda access to DynamoDB Photo table
const photoTable = backend.data.resources.tables['Photo'];
const personTable = backend.data.resources.tables['Person'];
const photoPersonTable = backend.data.resources.tables['PhotoPerson'];

if (photoTable) {
	photoTable.grantReadWriteData(analyzePhotoLambda);
	backend.analyzePhoto.addEnvironment('PHOTO_TABLE_NAME', photoTable.tableName);
}

if (personTable) {
	personTable.grantWriteData(analyzePhotoLambda);
	// Also grant Scan/Query for checking existing faces
	personTable.grantReadData(analyzePhotoLambda);
	backend.analyzePhoto.addEnvironment(
		'PERSON_TABLE_NAME',
		personTable.tableName,
	);
}

if (photoPersonTable) {
	photoPersonTable.grantWriteData(analyzePhotoLambda);
	backend.analyzePhoto.addEnvironment(
		'PHOTOPERSON_TABLE_NAME',
		photoPersonTable.tableName,
	);
}

// Trigger Lambda when a photo is uploaded
s3Bucket.addEventNotification(
	EventType.OBJECT_CREATED,
	new LambdaDestination(analyzePhotoLambda),
	{ prefix: 'photos/' },
);
