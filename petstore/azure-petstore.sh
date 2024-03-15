
##### Resource Group #####
az group create -l eastus -n homopetstorerg

#####  Application Container Registry #####
az acr create \
     --resource-group homopetstorerg \
     --name homopetstorecr \
     --sku Basic \
     --admin-enabled true


#####  Service Plan for all API Services #####
az appservice plan create \
    --name homopetstoreserviceasp \
    --resource-group homopetstorerg \
    --location eastus \
    --sku S1 \
    --is-linux \

##### Auto Scaling #####
az monitor autoscale create \
    --resource-group homopetstorerg \
    --resource homopetstoreserviceasp \
    --resource-type Microsoft.Web/serverfarms \
    --min-count 1 \
    --max-count 3 \
    --count 1

##### Rules for Auto Scaling #####
az monitor autoscale rule create -g homopetstorerg --autoscale-name homopetstoreserviceasp --scale out 1 --condition "CpuPercentage > 70 avg 5m"
az monitor autoscale rule create -g homopetstorerg --autoscale-name homopetstoreserviceasp --scale in 1 --condition "CpuPercentage < 25 avg 5m"

##### Pet Service #####
az webapp create \
     --resource-group homopetstorerg \
     --plan homopetstoreserviceasp \
     --name homopetstorepetservice \
     --deployment-container-image-name homopetstorecr.azurecr.io/petstorepetservice:latest

##### Product Service #####
az webapp create \
     --resource-group homopetstorerg \
     --plan homopetstoreserviceasp \
     --name homopetstoreproductservice \
     --deployment-container-image-name homopetstorecr.azurecr.io/petstoreproductservice:latest

##### Order Service #####
az webapp create \
     --resource-group homopetstorerg \
     --plan homopetstoreserviceasp \
     --name homopetstoreorderservice \
     --deployment-container-image-name homopetstorecr.azurecr.io/petstoreorderservice:latest

PETSTOREPETSERVICE_URL=$(az webapp config hostname list --resource-group homopetstorerg --webapp-name homopetstorepetservice --query "[].name" -o tsv)
PETSTOREPRODUCTSERVICE_URL=$(az webapp config hostname list --resource-group homopetstorerg --webapp-name homopetstoreproductservice --query "[].name" -o tsv)
PETSTOREORDERSERVICE_URL=$(az webapp config hostname list --resource-group homopetstorerg --webapp-name homopetstoreorderservice --query "[].name" -o tsv)


#####  Service Plan for Petstore App - East US #####
az appservice plan create \
    --name homopetstoreeastusasp \
    --resource-group homopetstorerg \
    --location eastus \
    --sku B1 \
    --is-linux \

##### Petstore App - East US #####
az webapp create \
     --resource-group homopetstorerg \
     --plan homopetstoreeastusasp \
     --name homopetstoreeastusapp \
     --deployment-container-image-name homopetstorecr.azurecr.io/petstoreapp:latest

az acr credential show

az webapp config appsettings set -g homopetstorerg -n homopetstoreeastusapp \
    --settings \
        PETSTOREPETSERVICE_URL=https://$PETSTOREPETSERVICE_URL \
        PETSTOREPRODUCTSERVICE_URL=https://$PETSTOREPRODUCTSERVICE_URL \
        PETSTOREORDERSERVICE_URL=https://$PETSTOREORDERSERVICE_URL

#####  Service Plan for Petstore App - West Europe #####
az appservice plan create \
     --name homopetstorewesteuropeasp \
     --resource-group homopetstorerg \
     --location westeurope \
     --sku B1 \
     --is-linux

##### Petstore App - West Europe #####
az webapp create \
     --resource-group homopetstorerg \
     --plan homopetstorewesteuropeasp \
     --name homopetstorewesteuropeapp \
     --deployment-container-image-name homopetstorecr.azurecr.io/petstoreapp:latest

az acr credential show

az webapp config appsettings set -g homopetstorerg -n homopetstorewesteuropeapp \
    --settings \
        PETSTOREPETSERVICE_URL=https://$PETSTOREPETSERVICE_URL \
        PETSTOREPRODUCTSERVICE_URL=https://$PETSTOREPRODUCTSERVICE_URL \
        PETSTOREORDERSERVICE_URL=https://$PETSTOREORDERSERVICE_URL


##### push docker images #####

az acr login --name homopetstorecr

cd petstoreorderservice || exit
#docker build -t petstoreorderservice .
docker tag petstoreorderservice:latest homopetstorecr.azurecr.io/petstoreorderservice:latest
docker push homopetstorecr.azurecr.io/petstoreorderservice:latest
cd ..

cd petstoreproductservice || exit
#docker build -t petstoreproductservice .
docker tag petstoreproductservice:latest homopetstorecr.azurecr.io/petstoreproductservice:latest
docker push homopetstorecr.azurecr.io/petstoreproductservice:latest
cd ..

cd petstorepetservice || exit
#docker build -t petstorepetservice .
docker tag petstorepetservice:latest homopetstorecr.azurecr.io/petstorepetservice:latest
docker push homopetstorecr.azurecr.io/petstorepetservice:latest
cd ..

cd petstoreapp || exit
#docker build -t petstoreapp .
docker tag petstoreapp:latest homopetstorecr.azurecr.io/petstoreapp:latest
docker push homopetstorecr.azurecr.io/petstoreapp:latest
cd ..
