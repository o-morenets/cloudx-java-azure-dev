RG=homopetstorerg
CR=homopetstorecr
SERVICES_ASP=homopetstoreserviceasp
APP_EASTUS=homopetstoreeastusapp
APP_EASTUS_ASP=homopetstoreeastusasp
APP_WESTEUROPE=homopetstorewesteuropeapp
APP_WESTEUROPE_ASP=homopetstorewesteuropeasp
PET_SERVICE=homopetstorepetservice
PRODUCT_SERVICE=homopetstoreproductservice
ORDER_SERVICE=homopetstoreorderservice
IMAGE_PET_SERVICE=petstorepetservice
IMAGE_PRODUCT_SERVICE=petstoreproductservice
IMAGE_ORDER_SERVICE=petstoreorderservice
IMAGE_PETSTORE_APP=petstoreapp

##### Resource Group #####
az group create -l eastus -n $RG

#####  Application Container Registry #####
az acr create \
     --resource-group $RG \
     --name $CR \
     --sku Basic \
     --admin-enabled true


#####  Service Plan for all API Services #####
az appservice plan create \
    --name $SERVICES_ASP \
    --resource-group $RG \
    --location eastus \
    --sku S1 \
    --is-linux \

##### Auto Scaling #####
az monitor autoscale create \
    --resource-group $RG \
    --resource $SERVICES_ASP \
    --resource-type Microsoft.Web/serverfarms \
    --min-count 1 \
    --max-count 3 \
    --count 1

##### Rules for Auto Scaling #####
az monitor autoscale rule create \
    --resource-group $RG \
    --autoscale-name $SERVICES_ASP \
    --scale out 1 \
    --condition "CpuPercentage > 70 avg 5m"
az monitor autoscale rule create \
    --resource-group $RG \
    --autoscale-name $SERVICES_ASP \
    --scale in 1 \
    --condition "CpuPercentage < 25 avg 5m"


##### Pet Service #####
az webapp create \
     --resource-group $RG \
     --plan $SERVICES_ASP \
     --name $PET_SERVICE \
     --deployment-container-image-name $CR.azurecr.io/$IMAGE_PET_SERVICE:latest

##### Product Service #####
az webapp create \
     --resource-group $RG \
     --plan $SERVICES_ASP \
     --name $PRODUCT_SERVICE \
     --deployment-container-image-name $CR.azurecr.io/$IMAGE_PRODUCT_SERVICE:latest

##### Order Service #####
az webapp create \
     --resource-group $RG \
     --plan $SERVICES_ASP \
     --name $ORDER_SERVICE \
     --deployment-container-image-name $CR.azurecr.io/$IMAGE_ORDER_SERVICE:latest

PETSTOREPETSERVICE_URL=$(az webapp config hostname list --resource-group $RG --webapp-name $PET_SERVICE --query "[].name" -o tsv)
PETSTOREPRODUCTSERVICE_URL=$(az webapp config hostname list --resource-group $RG --webapp-name $PRODUCT_SERVICE --query "[].name" -o tsv)
PETSTOREORDERSERVICE_URL=$(az webapp config hostname list --resource-group $RG --webapp-name $ORDER_SERVICE --query "[].name" -o tsv)


#####  Service Plan for Petstore App - East US #####
az appservice plan create \
    --name $APP_EASTUS_ASP \
    --resource-group $RG \
    --location eastus \
    --sku S1 \
    --is-linux \

##### Petstore App - East US #####
az webapp create \
     --resource-group $RG \
     --plan $APP_EASTUS_ASP \
     --name $APP_EASTUS \
     --deployment-container-image-name $CR.azurecr.io/$IMAGE_PETSTORE_APP:latest

##### Environment variables #####
az webapp config appsettings set \
    --resource-group $RG \
    --name $APP_EASTUS \
    --settings \
        PETSTOREPETSERVICE_URL=https://$PETSTOREPETSERVICE_URL \
        PETSTOREPRODUCTSERVICE_URL=https://$PETSTOREPRODUCTSERVICE_URL \
        PETSTOREORDERSERVICE_URL=https://$PETSTOREORDERSERVICE_URL

##### Staging Slot #####
az webapp deployment slot create \
    --name $APP_EASTUS \
    --resource-group $RG \
    --slot staging \
    --configuration-source $APP_EASTUS

##### Enable CI/CD for staging slot #####
az webapp deployment container config \
    --enable-cd true \
    --name $APP_EASTUS \
    --slot staging \
    --resource-group $RG


#####  Service Plan for Petstore App - West Europe #####
az appservice plan create \
     --name $APP_WESTEUROPE_ASP \
     --resource-group $RG \
     --location westeurope \
     --sku S1 \
     --is-linux

##### Petstore App - West Europe #####
az webapp create \
     --resource-group $RG \
     --plan $APP_WESTEUROPE_ASP \
     --name $APP_WESTEUROPE \
     --deployment-container-image-name $CR.azurecr.io/$IMAGE_PETSTORE_APP:latest

##### Environment variables #####
az webapp config appsettings set \
    --resource-group $RG \
    --name $APP_WESTEUROPE \
    --settings \
        PETSTOREPETSERVICE_URL=https://$PETSTOREPETSERVICE_URL \
        PETSTOREPRODUCTSERVICE_URL=https://$PETSTOREPRODUCTSERVICE_URL \
        PETSTOREORDERSERVICE_URL=https://$PETSTOREORDERSERVICE_URL


##### push docker images #####

az acr login --name $CR

cd $IMAGE_PET_SERVICE || exit
#docker build -t $IMAGE_PET_SERVICE .
docker tag $IMAGE_PET_SERVICE:latest $CR.azurecr.io/$IMAGE_PET_SERVICE:latest
docker push $CR.azurecr.io/$IMAGE_PET_SERVICE:latest
cd ..

cd $IMAGE_PRODUCT_SERVICE || exit
#docker build -t $IMAGE_PRODUCT_SERVICE .
docker tag $IMAGE_PRODUCT_SERVICE:latest $CR.azurecr.io/$IMAGE_PRODUCT_SERVICE:latest
docker push $CR.azurecr.io/$IMAGE_PRODUCT_SERVICE:latest
cd ..

cd $IMAGE_ORDER_SERVICE || exit
#docker build -t $IMAGE_ORDER_SERVICE .
docker tag $IMAGE_ORDER_SERVICE:latest $CR.azurecr.io/$IMAGE_ORDER_SERVICE:latest
docker push $CR.azurecr.io/$IMAGE_ORDER_SERVICE:latest
cd ..

cd $IMAGE_PETSTORE_APP || exit
#docker build -t $IMAGE_PETSTORE_APP .
docker tag $IMAGE_PETSTORE_APP:latest $CR.azurecr.io/$IMAGE_PETSTORE_APP:latest
docker push $CR.azurecr.io/$IMAGE_PETSTORE_APP:latest
cd ..
