
CUSTOM_FILE ?= custom.mk
ifneq ("$(wildcard $(CUSTOM_FILE))","")
  include $(CUSTOM_FILE)
endif

PROFILE ?= default
ROOT ?= $(shell pwd)
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --profile $(PROFILE) --query 'Account' --output text)
ENV ?= dev
AZ_1 ?= us-west-1b
AZ_2 ?= us-west-1c
SSH_KEY_NAME ?= rnzdev
MFA ?= true
DB_USER ?= admin$(ENV)
DB_PASS ?= g3nthDWxsh490czlLcIPO
DB_SIZE ?= 100
DB_NAME ?= api$(ENV)
DB_ENGINE ?= postgres
DB_INSTANCE_TYPE ?= db.t3.small
STACK ?= python3
CERT_ARN ?= arn:aws:acm:us-west-1:$(AWS_ACCOUNT_ID):certificate/a76117a1-ce24-4d5f-82c8-7a9f80f8019f
MIN_INSTANCE_COUNT ?= 1
MAX_INSTANCE_COUNT ?= 4
LB_PORT ?= 443
APP_PORT ?= 80
APP ?= $(PROFILE)
REGION ?= us-west-1
STACK_NAME ?= api-$(ENV)
INSTANCE_TYPE ?= t3.small
STACK_BUCKET ?= eb-stack-$(ENV)-$(AWS_ACCOUNT_ID)-$(REGION)

.PHONY: release
release:
	@zip  --exclude=*.git* --exclude=*.swp* --exclude=Makefile --exclude=*cfn* -r $(STACK_NAME).zip .
	@aws s3 cp --profile $(PROFILE) --region $(REGION) $(STACK_NAME).zip s3://$(STACK_BUCKET)/$(STACK_NAME).zip

.PHONY: bootstrap
bootstrap:
	@aws s3api create-bucket \
	--profile $(PROFILE) \
	--region $(REGION) \
	--bucket $(STACK_BUCKET) \
	--create-bucket-configuration LocationConstraint=$(REGION)
	@zip  --exclude=*.git* --exclude=*.swp* --exclude=Makefile --exclude=*cfn* -r $(STACK_NAME).zip .
	@aws s3 cp --profile $(PROFILE) --region $(REGION) $(STACK_NAME).zip s3://$(STACK_BUCKET)/$(STACK_NAME).zip
	@aws s3 sync --profile $(PROFILE) --region $(REGION) --exclude "*.swp" cfn s3://$(STACK_BUCKET)
	@aws cloudformation create-stack \
  --stack-name $(STACK_NAME) \
	--profile $(PROFILE) \
	--region $(REGION) \
  --template-url https://s3.amazonaws.com/$(STACK_BUCKET)/vpc-bastion-eb-rds.cfn.yml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
  ParameterKey=TemplateBucket,ParameterValue=$(STACK_BUCKET) \
  ParameterKey=EnvironmentName,ParameterValue=$(ENV) \
  ParameterKey=AvailabilityZone1,ParameterValue=$(AZ_1) \
  ParameterKey=AvailabilityZone2,ParameterValue=$(AZ_2) \
  ParameterKey=ELBIngressPort,ParameterValue=$(LB_PORT) \
  ParameterKey=AppIngressPort,ParameterValue=$(APP_PORT) \
  ParameterKey=KeyName,ParameterValue=$(SSH_KEY_NAME) \
  ParameterKey=EC2KeyPairName,ParameterValue=$(SSH_KEY_NAME) \
  ParameterKey=MFA,ParameterValue=$(MFA) \
  ParameterKey=StackType,ParameterValue=$(STACK) \
  ParameterKey=AppS3Bucket,ParameterValue=$(STACK_BUCKET) \
  ParameterKey=AppS3Key,ParameterValue=$(STACK_NAME).zip \
  ParameterKey=EbInstanceType,ParameterValue=$(INSTANCE_TYPE) \
  ParameterKey=SSLCertificateArn,ParameterValue=$(CERT_ARN) \
  ParameterKey=AutoScalingMinInstanceCount,ParameterValue=$(MIN_INSTANCE_COUNT) \
  ParameterKey=AutoScalingMaxInstanceCount,ParameterValue=$(MAX_INSTANCE_COUNT) \
  ParameterKey=DatabaseUser,ParameterValue=$(DB_USER) \
  ParameterKey=DatabaseName,ParameterValue=$(DB_NAME) \
  ParameterKey=DatabasePassword,ParameterValue=$(DB_PASS) \
  ParameterKey=DatabaseEngine,ParameterValue=$(DB_ENGINE) \
  ParameterKey=EncryptionAtRest,ParameterValue=true \
  ParameterKey=DatabaseEnhancedMonitoring,ParameterValue=true \
  ParameterKey=DatabaseSize,ParameterValue=$(DB_SIZE) \
	ParameterKey=DatabaseInstanceClass,ParameterValue=$(DB_INSTANCE_TYPE) \
	ParameterKey=DatabaseEnableAlarms,ParameterValue=true
