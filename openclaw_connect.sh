#!/bin/bash

STACK_NAME="openclaw-agentcore"
REGION="us-east-1"

echo "🦞 OpenClaw 접속 스크립트"
echo "=========================="
echo ""

# 입력 받기
read -p "AWS Profile 이름 [default]: " PROFILE
PROFILE=${PROFILE:-default}

echo ""
echo "✅ Stack: $STACK_NAME"
echo "✅ Region: $REGION"
echo "✅ Profile: $PROFILE"
echo ""

# Instance ID 가져오기
echo "1️⃣ Instance ID 가져오는 중..."
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
    echo "❌ Instance ID를 가져올 수 없습니다."
    exit 1
fi
echo "✅ Instance ID: $INSTANCE_ID"

# Gateway Token 가져오기
echo ""
echo "2️⃣ Gateway Token 가져오는 중..."
GATEWAY_TOKEN=$(aws ssm get-parameter \
  --name "/openclaw/$STACK_NAME/gateway-token" \
  --region $REGION \
  --profile $PROFILE \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text)

if [ -z "$GATEWAY_TOKEN" ]; then
    echo "❌ Gateway Token을 가져올 수 없습니다."
    exit 1
fi
echo "✅ Gateway Token: $GATEWAY_TOKEN"

# 브라우저 URL
URL="http://localhost:18789/?token=$GATEWAY_TOKEN"

echo ""
echo "3️⃣ 브라우저 열기..."
echo "URL: $URL"

# macOS에서 브라우저 열기
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$URL"
    echo "✅ 브라우저가 열렸습니다."
else
    echo "⚠️  수동으로 브라우저를 열어주세요: $URL"
fi

echo ""
echo "4️⃣ 포트 포워딩 시작 (이 터미널을 열어두세요)..."
echo "종료하려면 Ctrl+C를 누르세요."
echo ""

# 포트 포워딩 시작
aws ssm start-session \
  --target $INSTANCE_ID \
  --region $REGION \
  --profile $PROFILE \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
