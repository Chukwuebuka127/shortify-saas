const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { randomBytes } = require("crypto");

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);

exports.handler = async (event) => {
  const body = JSON.parse(event.body || "{}");
  const longUrl = body.url;

  if (!longUrl) {
    return { statusCode: 400, body: JSON.stringify({ error: "Missing 'url' field" }) };
  }

  const shortCode = randomBytes(4).toString("hex");

  await ddb.send(new PutCommand({
    TableName: process.env.TABLE_NAME,
    Item: { short_code: shortCode, long_url: longUrl, clicks: 0 }
  }));

  return {
    statusCode: 201,
    body: JSON.stringify({ short_code: shortCode })
  };
};
