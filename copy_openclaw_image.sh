#!/bin/bash
set -e

echo "🐳 OpenClaw 공개 이미지를 ECR로 복사"
echo "===================================="
echo ""

# 입력 받기
read -p "AWS Profile 이름 [default]: " PROFILE
PROFILE=${PROFILE:-default}

read -p "AWS Region [us-east-1]: " REGION
REGION=${REGION:-us-east-1}

# Account ID 가져오기
echo ""
echo "📋 AWS Account ID 가져오는 중..."
ACCOUNT_ID=$(aws sts get-caller-identity --profile $PROFILE --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ AWS Account ID를 가져올 수 없습니다. Profile을 확인하세요."
    exit 1
fi

echo "✅ Account ID: $ACCOUNT_ID"
echo "✅ Profile: $PROFILE"
echo "✅ Region: $REGION"
echo ""

ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/openclaw-agentcore-agent"

# ECR 리포지토리 생성 (이미 존재하면 무시)
echo "1️⃣ ECR 리포지토리 확인/생성 중..."
if aws ecr describe-repositories --repository-names openclaw-agentcore-agent --region $REGION --profile $PROFILE >/dev/null 2>&1; then
    echo "✅ ECR 리포지토리가 이미 존재합니다."
else
    echo "📦 ECR 리포지토리 생성 중..."
    aws ecr create-repository \
        --repository-name openclaw-agentcore-agent \
        --region $REGION \
        --profile $PROFILE >/dev/null
    echo "✅ ECR 리포지토리 생성 완료"
fi

# ECR 로그인
echo ""
echo "2️⃣ ECR 로그인 중..."
aws ecr get-login-password --region ${REGION} --profile ${PROFILE} | \
    docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

# 공개 이미지 Pull
echo ""
echo "3️⃣ 공개 이미지 다운로드 중..."
docker pull alpine/openclaw:latest

# 태그
echo ""
echo "4️⃣ 이미지 태그 중..."
docker tag alpine/openclaw:latest ${ECR_REPO}:latest

# Push
echo ""
echo "5️⃣ ECR로 푸시 중..."
docker push ${ECR_REPO}:latest

echo ""
echo "✅ 완료!"
echo "=================================="
echo "이미지 URI: ${ECR_REPO}:latest"
echo ""
echo "다음 단계:"
echo "  CloudFormation 스택을 배포하세요."
echo "  aws cloudformation create-stack \\"
echo "    --stack-name openclaw-agentcore \\"
echo "    --template-body file://clawdbot-bedrock-agentcore.yaml \\"
echo "    --capabilities CAPABILITY_NAMED_IAM \\"
echo "    --region ${REGION} \\"
echo "    --profile ${PROFILE} \\"
echo "    --parameters \\"
echo "      ParameterKey=KeyPairName,ParameterValue=YOUR_KEY_PAIR \\"
echo "      ParameterKey=InstanceType,ParameterValue=t4g.small \\"
echo "      ParameterKey=OpenClawModel,ParameterValue=global.amazon.nova-2-lite-v1:0 \\"
echo "      ParameterKey=EnableAgentCore,ParameterValue=true \\"
echo "      ParameterKey=CreateVPCEndpoints,ParameterValue=false"
