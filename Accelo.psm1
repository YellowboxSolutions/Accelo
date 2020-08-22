$AcceloSession = [ordered]@{
    User            = $null
    Secret          = $null
    BaseUri         = $null
    AccessToken     = $null
    RefreshToken    = $null
    ConnectTime             = $null
    ElapsedTime             = $null
}
New-Variable -Name AcceloSession -Value $AcceloSession -Scope Script -Force

function Get-AcceloUri {
    [CmdletBinding()]
    param (
        # Uri
        [Parameter(Mandatory)]
        [Uri]$uri,
        [string]$path,
        [int]$limit,
        [string]$filters,
        [string]$fields
    )
    
    begin {
    }
    
    process {
        $UriBuilder = [UriBuilder]$uri

        if (($filters) -or ($fields) -or ($limit)) {
            $queryCollection = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
            if ($limit) {
                $queryCollection.add("_limit", $limit)
            }
            if ($filters) {
                $queryCollection.add("_filters", $filters)
            }
            if ($fields) {
                $queryCollection.add("_fields", $fields)
            }
            $UriBuilder.Query = $queryCollection.ToString()

        }

        if ($path) {
            $UriBuilder.Path = $path
        }
        $UriBuilder.Uri
    }
    
    end {
        
    }
}

function Invoke-Accelo{
    [Cmdletbinding(DefaultParameterSetName="InvokeUriString")]
    param (
        [Parameter(Mandatory)]
        [Uri]$uri,

        [string]$method = "GET",

        [hashtable]$headers,

        [hashtable]$body
    )

    Begin {

    }

    Process {
        $invokeSplat = @{
            method = $method
            uri = $uri
        }
        
        if (($headers) -and ($headers.ContainsKey('Authorization'))) {
            $invokeSplat.add('headers', $headers)
        } elseif ($AcceloSession.AccessToken) {
            $invokeSplat.add('headers', @{Authorization = "Bearer $($AcceloSession.AccessToken)"})
        } else {
            write-error "No Auth info provided"
        }
        
        if ($body) {
            $invokeSplat.add('body', $body)
        }
        try{
            $invocation = Invoke-WebRequest @invokeSplat
        } catch {
            write-error "Accelo request broke: $_"
            return
        }
        write-verbose $invocation
        $response = $invocation.Content|ConvertFrom-Json
        $response
    }

    End {

    }
}

function Connect-Accelo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$User,

        [Parameter(Mandatory)]
        [SecureString]$Secret,

        [Parameter(Mandatory)]
        [string]$BaseUri,

        [string]$Scope = "read(all)"
    )
    
    begin {
        $AcceloSession.User = $User
        $AcceloSession.Secret = $Secret
        $AcceloSession.BaseUri = [Uri]$BaseUri.TrimEnd()
        $AcceloSession.ConnectTime = [System.DateTime]::Now
        $AcceloSession.ElapsedTime = [System.Diagnostics.Stopwatch]::StartNew()

        $OAuthUri = Get-AcceloUri -uri $AcceloSession.Baseuri -path "/oauth2/v0/token"

        $body = @{
            grant_type = "client_credentials"
            scope = $scope
        }

        $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $AcceloSession.User,$AcceloSession.Secret

        $authinfo = ("{0}:{1}" -f $($Credential.UserName), $($Credential.GetNetworkCredential().password))
        $authinfo = [System.Text.Encoding]::UTF8.GetBytes($authinfo)
        $authinfo = [System.Convert]::ToBase64String($authinfo)

        $headers = @{ Authorization = "Basic $authinfo"}
    }
    
    process {
        $invocation = Invoke-Accelo -Method POST -uri $OAuthUri -body $body -Headers $headers
        $AcceloSession.AccessToken = $invocation.access_token
        $AcceloSession.RefreshToken = $invocation.refresh_token
        $AcceloSession
    }
    
    end {
        
    }
}

function Get-AcceloSession {
    $AcceloSession | ConvertTo-Json | ConvertFrom-Json
}

function Get-AcceloCompany {
    [Cmdletbinding(DefaultParametersetName="GetCompany")]
    param(
        # Company Id
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetCompanyById")]
        [string]
        $Id,

        [Parameter(ParametersetName="GetCompany")]
        [int]$limit,

        [Parameter(ParametersetName="GetCompany")]
        [string]$filters,

        [Parameter(ParametersetName="GetCompany")]
        [string]$fields
    )

    Begin {

    }


    Process {
        $UriPath = $null
        switch ($PSCmdlet.parametersetname) {
            'GetCompany' { 
                $UriPath = "api/v0/companies"
            }

            'GetCompanyById' {
                $UriPath =  "api/v0/companies/$Id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $query = @{"_filters" = $filters; "_fields" = $fields}
        
        $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
        $company = (Invoke-Accelo -uri $uri).response
        $company
    }
}

function Get-AcceloRequest {
    [CmdletBinding(DefaultParameterSetName="GetRequest")]
    param (

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetRequestById")]
        [string]$id,

        [Parameter()]
        [int]$limit,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )
    
    begin {
        
    }
    
    process {
        $UriPath = $null
        switch ($PSCmdlet.parametersetname) {
            'GetRequest' { 
                $UriPath = "$($uriObject.path)/api/v0/requests"
            }

            'GetRequestById' {
                $UriPath = "$($uriObject.path)/api/v0/requests/$id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
        
        $requests = (Invoke-Accelo -uri $Uri).response
        $requests
    }
    
    end {
        
    }
}

function Add-AcceloRequest {
    [CmdletBinding(DefaultParameterSetName="AddRequest")]
    param (
        [Parameter(Mandatory, ParameterSetName="AddRequest")]
        [string]$typeId,

        [Parameter(Mandatory, ParameterSetName="AddRequest")]
        [string]$title,

        [Parameter(Mandatory, ParameterSetName="AddRequest")]
        [string]$affiliationId,

        [Parameter(Mandatory, ParameterSetName="AddRequest")]
        [string]$body

    )
    
    begin {
        $uriObject = [System.Uribuilder]$uri
        $uriObject.path = "$($uriObject.path)/requests"
        $headers = @{
            "Authorization" = "Bearer $token"
        }
    }
    
    process {
        $acceloRequest = @{
            type_id = $typeId
            title = $title
            body = $body
            affiliation_id = $affiliationId
        }

        $request = (Invoke-Accelo -headers $headers -method "POST" -uri $uriObject -body $acceloRequest).response
        $request
    }
    
    end {
        
    }
}

function Get-AcceloAffiliation {
    [Cmdletbinding(DefaultParameterSetName="GetAffiliation")]
    param(

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetAffiliationById")]
        [string]$Id,
        
        [Parameter()]
        [int]$limit,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )

    Begin {
    }


    Process {
        $UriPath = $null
        switch ($PSCmdlet.ParameterSetName) {
            'GetAffiliation' { 
                $UriPath = "/api/v0/affiliations"
            }

            'GetAffiliationById' {
                $UriPath = "/api/v0/affiliations/$Id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
        $affiliations = (Invoke-Accelo -uri $Uri).response
        $affiliations
    }
}

function Get-AcceloRequestType {
    [Cmdletbinding(DefaultParameterSetName="GetRequestType")]
    param(
        
        [Parameter()]
        [int]$limit,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )

    Begin {
    }


    Process {
        $UriPath = $null
        switch ($PSCmdlet.ParameterSetName) {
            'GetRequestType' { 
                $UriPath = "/api/v0/requests/types"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
        $RequestTypes = (Invoke-Accelo -uri $Uri).response.request_types
        $RequestTypes
    }
}
Export-ModuleMember -Function Get-AcceloUri,Connect-Accelo,Invoke-Accelo,*-AcceloToken,*-AcceloRequest*,*-AcceloCompan*,*-AcceloAffiliation*,Get-AcceloSession