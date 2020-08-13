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
        [Uri]
        $uri,
        [string]$path,
        
        [hashtable]$query
    )
    
    begin {
    }
    
    process {
        $UriBuilder = [UriBuilder]$uri
        Add-Type -AssemblyName System.Web
        $queryCollection = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        
        foreach ($key in $query.Keys) {
            if ($query.$key) {
                $queryCollection.add($key, $query.$key)
            }
        }
        $UriBuilder.Query = $queryCollection.ToString()
        $UriBuilder.Path = $path
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

        [hashtable]$query,
        
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
    [Cmdletbinding(DefaultParameterSetName="GetCompany")]
    param(
        # Company Id
        [Parameter(Mandatory,ParameterSetName="GetCompanyById")]
        [string]
        $Id,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )

    Begin {
        $uriObject = [System.Uribuilder]$AcceloSession.BaseUri
        switch ($PSCmdlet.parametersetname) {
            'GetCompany' { 
                $uriObject.path = "$($uriObject.path)api/v0/companies"
            }

            'GetCompanyById' {
                $uriObject.path = "$($uriObject.path)api/v0/companies/$Id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $query = @{"_filters" = $filters; "_fields" = $fields}
    }


    Process {
        $company = (Invoke-Accelo -uri $uriObject.uri -headers $headers -query $query).response
        $company
    }
}

function Get-AcceloRequests {
    [CmdletBinding(DefaultParameterSetName="GetRequests")]
    param (

        [Parameter(Mandatory, ParameterSetName="GetRequestById")]
        [string]$id,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )
    
    begin {
        $uriObject = [System.Uribuilder]$uri
        switch ($PSCmdlet.parametersetname) {
            'GetRequests' { 
                $uriObject.path = "$($uriObject.path)/requests"
            }

            'GetRequestById' {
                $uriObject.path = "$($uriObject.path)/requests/$id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $headers = @{
            "Authorization" = "Bearer $token"
        }
        $query = @{"_filters" = $filters; "_fields" = $fields}
        
    }
    
    process {
        
        $requests = (Invoke-Accelo -uri $uriObject -headers $headers -query $query).response
        $requests
    }
    
    end {
        
    }
}

function Add-AcceloRequest {
    [CmdletBinding(DefaultParameterSetName="AddRequest")]
    param (
        [Parameter(Mandatory)]
        [string]$uri,

        [Parameter(Mandatory, ParameterSetName="AddRequest")]
        [string]$token,

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

function Get-AcceloAffiliations {
    [Cmdletbinding(DefaultParameterSetName="GetAffiliations")]
    param(
        [Parameter(Mandatory)]
        [string]$uri,

        [Parameter(Mandatory,ParameterSetName="GetAffiliations")]
        [Parameter(Mandatory,ParameterSetName="GetAffiliationsById")]
        [string]$token,

        [Parameter(Mandatory,ParameterSetName="GetAffiliationsById")]
        [string]$affiliationId,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )

    Begin {
        $uriObject = [System.Uribuilder]$uri
        switch ($PSCmdlet.ParameterSetName) {
            'GetAffiliations' { 
                $uriObject.path = "$($uriObject.path)/affiliations"
            }

            'GetAffiliationsById' {
                $uriObject.path = "$($uriObject.path)/affiliations/$affiliationId"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $query = @{"_filters" = $filters; "_fields" = $fields}
        $headers = @{
            "Authorization" = "Bearer $token"
        }
    }


    Process {
        $affiliations = (Invoke-Accelo -uri $uriObject -headers $headers -query $query).response
        $affiliations
    }
}

Export-ModuleMember -Function Get-AcceloUri,Connect-Accelo,Invoke-Accelo,*-AcceloToken,*-AcceloRequest*,*-AcceloCompan*,*-AcceloAffiliation*,Get-AcceloSession