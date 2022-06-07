#!/bin/bash

PROJ_NAME=$1
PROJ_PATH=`pwd`/$PROJ_NAME

echo "Setting up your project $PROJ_NAME"

mkdir $PROJ_NAME

mkdir $PROJ_NAME/stacks
mkdir $PROJ_NAME/me
mkdir $PROJ_NAME/apps
mkdir $PROJ_NAME/infra
mkdir $PROJ_NAME/host
mkdir $PROJ_NAME/secrets
mkdir $PROJ_NAME/bin

cd $PROJ_NAME

echo "KUBECONFIG=$PROJ_NAME/me/kube/config" > me/dev.env
echo "HELM_HOME=$PROJ_NAME/me/helm" >> me/dev.env
echo "MINFRA_HOST_PATH=$PROJ_PATH" >> me/dev.env
