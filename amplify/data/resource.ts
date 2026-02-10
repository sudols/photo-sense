import { type ClientSchema, a, defineData } from '@aws-amplify/backend';

const schema = a.schema({
	Photo: a
		.model({
			s3Key: a.string().required(),
			faceIds: a.string().array(),
			detectedText: a.string().array(),
			facesCount: a.integer().default(0),
			analyzedAt: a.datetime(),
		})
		.authorization((allow) => [allow.owner()]),

	Person: a
		.model({
			name: a.string().required(),
			faceId: a.string(),
			thumbnailS3Key: a.string(),
		})
		.authorization((allow) => [allow.owner()]),

	PhotoPerson: a
		.model({
			photoId: a.id().required(),
			personId: a.id().required(),
		})
		.authorization((allow) => [allow.owner()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
	schema,
	authorizationModes: {
		defaultAuthorizationMode: 'userPool',
	},
});
