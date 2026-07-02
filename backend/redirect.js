const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, UpdateCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  const shortCode = event.pathParameters.short_code;

  const result = await ddb.send(new GetCommand({
    TableName: process.env.TABLE_NAME,
    Key: { short_code: shortCode }
  }));

  if (!result.Item) {
    return { statusCode: 404, body: "Not found" };
  }

  await ddb.send(new UpdateCommand({
    TableName: process.env.TABLE_NAME,
    Key: { short_code: shortCode },
    UpdateExpression: "SET clicks = clicks + :inc",
    ExpressionAttributeValues: { ":inc": 1 }
  }));

  return {
    statusCode: 302,
    headers: { Location: result.Item.long_url }
  };
};
