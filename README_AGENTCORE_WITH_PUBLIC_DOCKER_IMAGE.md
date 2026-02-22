# OpenClaw on AWS with Bedrock AgentCore Runtime (공개 Docker 이미지 사용)

> 공개 Docker 이미지를 사용하여 OpenClaw를 AWS Bedrock AgentCore Runtime으로 빠르게 배포합니다. 소스 코드 빌드 없이 10-15분 내 배포 완료.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AWS](https://img.shields.io/badge/AWS-Bedrock-orange.svg)](https://aws.amazon.com/bedrock/)

## 왜 이 가이드인가?

기존 README_AGENTCORE.md는 OpenClaw 소스를 직접 빌드해야 하지만, 이 가이드는 **공개 Docker 이미지**를 사용하여:
- ✅ 소스 코드 클론 불필요
- ✅ Docker 빌드 시간 절약 (5-10분 단축)
- ✅ 설정 변경 없이 바로 사용 가능

## 빠른 시작 (10-15분)

### 사전 요구사항

- AWS CLI 설정 완료 (`aws configure`)
- Docker 실행 중
- EC2 Key Pair 생성됨
- AWS 계정 권한: CloudFormation, EC2, VPC, IAM, ECR, Bedrock AgentCore Runtime

### 배포 방법

#### 방법 1: 자동화 스크립트 사용 (권장)

```bash
# 1. 공개 이미지를 ECR로 복사 (대화형)
./copy_openclaw_image.sh

# 2. CloudFormation 배포 (스크립트 출력 참고)
```

#### 방법 2: 수동 배포

##### 1단계: ECR 리포지토리 생성

```bash
aws ecr create-repository \
  --repository-name openclaw-agentcore-agent \
  --region us-east-1 \
  --profile YOUR_PROFILE
```

##### 2단계: 공개 이미지를 ECR로 복사

```bash
# ECR 로그인
aws ecr get-login-password --region us-east-1 --profile YOUR_PROFILE | \
  docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# 공개 이미지 다운로드
docker pull alpine/openclaw:latest

# 태그 & 푸시
docker tag alpine/openclaw:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/openclaw-agentcore-agent:latest

docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/openclaw-agentcore-agent:latest
```

##### 3단계: CloudFormation 배포

```bash
aws cloudformation create-stack \
  --stack-name openclaw-agentcore \
  --template-body file://clawdbot-bedrock-agentcore.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --parameters \
    ParameterKey=KeyPairName,ParameterValue=YOUR_KEY_PAIR \
    ParameterKey=InstanceType,ParameterValue=t4g.small \
    ParameterKey=OpenClawModel,ParameterValue=global.amazon.nova-2-lite-v1:0 \
    ParameterKey=EnableAgentCore,ParameterValue=true \
    ParameterKey=CreateVPCEndpoints,ParameterValue=false
```

##### 4단계: 배포 완료 대기

```bash
aws cloudformation wait stack-create-complete \
  --stack-name openclaw-agentcore \
  --region us-east-1 \
  --profile YOUR_PROFILE
```

## 접속 방법

### 원클릭 접속 스크립트 (권장)

```bash
./openclaw_connect.sh

# 입력:
# AWS Profile 이름 [default]: YOUR_PROFILE
```

이 스크립트는 자동으로:
- ✅ Instance ID 조회
- ✅ Gateway Token 조회
- ✅ 브라우저 자동 열기
- ✅ 포트 포워딩 시작

### 수동 접속 방법

#### 1. 포트 포워딩 (터미널 열어두기)

```bash
# Instance ID 가져오기
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name openclaw-agentcore \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# 포트 포워딩 시작
aws ssm start-session \
  --target $INSTANCE_ID \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["18789"],"localPortNumber":["18789"]}'
```

#### 2. Gateway Token 가져오기

```bash
aws ssm get-parameter \
  --name "/openclaw/openclaw-agentcore/gateway-token" \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

#### 3. 브라우저 접속

```
http://localhost:18789/?token=<GATEWAY_TOKEN>
```

## 아키텍처

```
메시징 앱 → EC2 Gateway (t4g.small) → AgentCore Runtime → Bedrock (Nova 2 Lite)
```

**구성 요소:**
- **EC2 Gateway**: 메시징 채널 처리 (WhatsApp, Telegram, Discord)
- **AgentCore Runtime**: 서버리스 에이전트 실행 (자동 스케일링)
- **Bedrock**: Nova 2 Lite 모델 (90% 저렴)

## 비용 (월간)

| 항목 | 비용 |
|------|------|
| EC2 (t4g.small) | $12 |
| EBS (30GB) | $2.40 |
| VPC Endpoints | $0 (비활성화) |
| AgentCore Runtime | 종량제 (사용 시에만) |
| Bedrock (Nova 2 Lite) | $0.30/$2.50 per 1M tokens |
| **총 예상** | **$12-20/월** |

## 인스턴스 타입 옵션

| 타입 | 비용/월 | 스펙 | 권장 용도 |
|------|---------|------|-----------|
| **t4g.small** | **$12** | 2 vCPU, 2GB RAM | 개인 사용 (권장) |
| t4g.medium | $24 | 2 vCPU, 4GB RAM | 안정적 운영 |
| t4g.large | $48 | 2 vCPU, 8GB RAM | 다수 사용자 |
| c7g.large | $30-40 | 2 vCPU, 4GB RAM | 컴퓨팅 최적화 |

## 지원 모델

```yaml
OpenClawModel:
  - global.amazon.nova-2-lite-v1:0              # 기본, 90% 저렴
  - global.anthropic.claude-sonnet-4-5-20250929-v1:0  # 가장 강력
  - us.amazon.nova-pro-v1:0                     # 균형잡힌 성능
  - global.anthropic.claude-haiku-4-5-20251001-v1:0   # 빠르고 효율적
  - us.deepseek.r1-v1:0                         # 오픈소스 추론
  - us.meta.llama3-3-70b-instruct-v1:0          # 오픈소스 대안
```

## 메시징 플랫폼 연결

Web UI에서 다음 채널을 연결할 수 있습니다:

### WhatsApp (권장)
1. Web UI → "Channels" → "Add Channel" → "WhatsApp"
2. QR 코드 스캔 (WhatsApp 앱 → Settings → Linked Devices)
3. 테스트 메시지 전송

### Telegram
1. [@BotFather](https://t.me/botfather)에게 `/newbot` 전송
2. Bot Token 복사
3. Web UI에서 Telegram 채널 추가

### Discord
1. [Discord Developer Portal](https://discord.com/developers/applications)에서 Bot 생성
2. Bot Token 복사
3. Web UI에서 Discord 채널 추가

📖 **상세 가이드**: https://docs.clawd.bot/

## 채팅 명령어

| 명령어 | 설명 |
|--------|------|
| `/status` | 세션 상태 (모델, 토큰, 비용) |
| `/new` 또는 `/reset` | 새 대화 시작 |
| `/think high` | 깊은 사고 모드 활성화 |
| `/help` | 사용 가능한 명령어 표시 |

## 문제 해결

### 포트 포워딩 실패
- SSM Session Manager Plugin 설치 확인
- EC2 인스턴스 실행 상태 확인
- IAM 권한 확인

### Gateway 접속 불가
```bash
# Gateway 서비스 상태 확인
aws ssm start-session --target $INSTANCE_ID --region us-east-1 --profile YOUR_PROFILE
sudo systemctl --user status openclaw-gateway.service
```

### AgentCore 작동 안 함
```bash
# AgentCore Runtime ID 확인
aws cloudformation describe-stacks \
  --stack-name openclaw-agentcore \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --query 'Stacks[0].Outputs[?OutputKey==`AgentCoreRuntimeId`].OutputValue' \
  --output text
```

## 정리 (삭제)

```bash
# CloudFormation 스택 삭제
aws cloudformation delete-stack \
  --stack-name openclaw-agentcore \
  --region us-east-1 \
  --profile YOUR_PROFILE

# ECR 이미지 삭제 (선택사항)
aws ecr batch-delete-image \
  --repository-name openclaw-agentcore-agent \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --image-ids imageTag=latest

# ECR 리포지토리 삭제 (선택사항)
aws ecr delete-repository \
  --repository-name openclaw-agentcore-agent \
  --region us-east-1 \
  --profile YOUR_PROFILE \
  --force
```

## 기존 방식과 비교

| 항목 | 기존 (소스 빌드) | 이 가이드 (공개 이미지) |
|------|------------------|------------------------|
| 소스 클론 | ✅ 필요 | ❌ 불필요 |
| Docker 빌드 | ✅ 5-10분 | ❌ 불필요 |
| 설정 변경 | ✅ 가능 | ❌ 불가 (기본 설정) |
| 배포 시간 | 15-25분 | **10-15분** |
| 난이도 | 중급 | **초급** |

## 참고 자료

- [OpenClaw 공식 문서](https://docs.clawd.bot/)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [Amazon Bedrock 문서](https://docs.aws.amazon.com/bedrock/)
- [원본 가이드](README_AGENTCORE.md)

---

**Built with ❤️ for quick deployment**

공개 Docker 이미지를 사용하여 빠르게 개인 AI 어시스턴트를 배포하세요.
