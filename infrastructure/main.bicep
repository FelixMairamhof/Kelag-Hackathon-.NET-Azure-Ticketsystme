@description('Location where the ressources should be deployed to (optional). Per default, the same location as the provided resource group will be used.')
param location string = resourceGroup().location
@description('Name of the application (must not include spaces or special characters).')
param appName string
@description('Postfix that will be appended to ressource names. The postfix can be, for example, the name of the branch.')
param postfix string
@description('Full name of the container image including the version tag.')
param containerImageWithVersion string

@description('Username for authentication with the Container Registry (GitHub Packages)')
param registryUsername string

@description('Access  token for authentication with the Container Registry (GitHub Packages)')
@secure()
param registryToken string

var containerAppEnvironmentName = take('caenv-${appName}-${postfix}', 32)
var containerAppName = take('ca-${appName}-${postfix}', 32)
var logAnalyticsWorkspaceName = take('logs-${appName}-${postfix}', 32)

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'id-Forstsee-Hackathon-Team-7'
}

// Container App Setup
// Create log analytics workspace for container app environment
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location 
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Create container app environment and link it with the previously created log analytics workspace
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvironmentName 
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Create the container app in the previously created container app environment
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      secrets: [
        {
          name: 'github-token'
          value: registryToken
        }
        {
          name: 'keyvaultsecretshared'
          keyVaultUrl: 'https://kv-forstsee-hackathon.vault.azure.net/secrets/hackthonDbConnection/0982866f102b48cebcc8442af89dc087'
          identity: managedIdentity.id
        }
        {
          name: 'keyvaultsecretteam7'
          keyVaultUrl: 'https://db-keyvault-team7.vault.azure.net/secrets/db-keysecret/eda5f91d03b94eb581bce8b753182f9d'
          identity: managedIdentity.id
        }
        {
          name: 'keyvaultopenai'
          keyVaultUrl: 'https://db-keyvault-team7.vault.azure.net/secrets/openai-key/5e3f71c9df8e4716a6d0c502b20d70d4'
          identity: managedIdentity.id
        }
        {
          name: 'aikeysecret'
          keyVaultUrl: 'https://db-keyvault-team7.vault.azure.net/secrets/db-blueml-key/8600f417f2874d14bfdab65e0c61cfa1'
          identity: managedIdentity.id
        }
        {
          name: 'aikeysecretnew'
          keyVaultUrl: 'https://db-keyvault-team7.vault.azure.net/secrets/db-blueml-key-new/7aa8d5c715814c6ca4361674e5754179'
          identity: managedIdentity.id
        }
      ]
      registries: [
        {
          passwordSecretRef: 'github-token'
          server: 'ghcr.io'
          username: registryUsername
        }
      ] 
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: containerImageWithVersion
          env: [
            {
              name: 'keyvaultsharedenv'
              secretRef: 'keyvaultsecretshared'
            }
            {
              name: 'keyvaultteam7env'
              secretRef: 'keyvaultsecretteam7'
            }
            {
              name: 'apikeyllm'
              secretRef: 'keyvaultopenai'
            }
            {
              name: 'aidbkey'
              secretRef: 'aikeysecret'
            }
            {
              name: 'aidbkeynew'
              secreRef: 'aikeysecretnew'
            }
          ]
        }   
      ]
    }
  }
}

// Das Bicep-File kann beliebig erweitert und adaptiert werden.
