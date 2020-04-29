
function Get-AcceloUri {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$baseUri,
        [string]$endpoint = ""
    )
    
    begin {
        
    }
    
    process {

        $uriObject = [System.UriBuilder]$baseUri
        $uriObject.path = $($uriObject.path).trimEnd("/")
        $uriObject.path = "$($uriObject.path)/$endpoint"
        $uriObject
    }
    
    end {
        
    }
}

function Invoke-Accelo{
    [Cmdletbinding(DefaultParameterSetName="InvokeUriString")]
    param (
        [Parameter(Mandatory,ParameterSetName="InvokeUriString")]
        [System.UriBuilder]$uri,

        [string]$SessionVariable,

        [string]$method = "GET",

        [hashtable]$query,

        [hashtable]$headers,
        
        [hashtable]$body
    )

    Begin {
    }

    Process {
        Add-Type -AssemblyName System.Web
        $queryCollection = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        foreach ($key in $query.Keys) {
            if ($query.$key) {
                $queryCollection.add($key, $query.$key)
            }
        }
        $uri.Query = $queryCollection.ToString()

        $invokeSplat = @{
            method = $method
            headers = $headers
            uri = $uri.Uri.OriginalString
            SessionVariable = $SessionVariable
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

        $response = $invocation.Content|ConvertFrom-Json
        $response
    }

    End {

    }
}

function Get-AcceloToken {
    param (
        [Parameter(Mandatory)]
        [string]$uri,
        [Parameter(Mandatory)]
        [PSCredential]$credential,
        [string]$scope = "read(all)"
    )

    $tokenreq_body = @{
        grant_type = "client_credentials"
        scope = $scope
    }

    $authinfo = ("{0}:{1}" -f $($credential.username), $($credential.GetNetworkCredential().password))
    $authinfo = [System.Text.Encoding]::UTF8.GetBytes($authinfo)
    $authinfo = [System.Convert]::ToBase64String($authinfo)

    $headers = @{ Authorization = "Basic $authinfo"}

    $invocation = Invoke-Accelo -Method POST -uri $uri -body $tokenreq_body -Headers $headers
    $token = $invocation.access_token
    $token
}

function Connect-Accelo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$authUri,
        [Parameter(Mandatory)]
        [string]$baseUri,
        [string]$scope,
        [PSCredential]$credential
    )
    
    begin {
        $authEndpoint = "token"
        $authuri = Get-AcceloUri -baseUri $authUri `
        -endpoint $authEndpoint

        $apiEndpoint = "tokeninfo"
        $apiuri = Get-AcceloUri -baseUri $baseUri `
        -endpoint $apiEndpoint
    }
    
    process {
        $token = Get-AcceloToken -uri $authuri -credential $credential -scope $scope
        $headers = @{
            "Authorization" = "Bearer $token"
        }

        $response = Invoke-Accelo -uri $apiuri -headers $headers -SessionVariable "global:AcceloSession"
        $response
    }
    
    end {
        
    }
}

function Get-AcceloCompanies {
    [Cmdletbinding(DefaultParameterSetName="GetCompanies")]
    param(
        [Parameter(Mandatory)]
        [string]$uri,
        [Parameter(Mandatory,ParameterSetName="GetCompanies")]
        [Parameter(Mandatory,ParameterSetName="GetCompanyById")]
        [string]$token,

        [Parameter(Mandatory,ParameterSetName="GetCompanyById")]
        [string]$companyId,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )

    Begin {
        $uriObject = [System.Uribuilder]$uri
        switch ($PSCmdlet.parametersetname) {
            'GetCompanies' { 
                $uriObject.path = "$($uriObject.path)/companies"
            }

            'GetCompanyById' {
                $uriObject.path = "$($uriObject.path)/companies/$companyId"
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


    Process {
        $companies = (Invoke-Accelo -uri $uriObject -headers $headers -query $query).response
        $companies
    }
}

function Get-AcceloRequests {
    [CmdletBinding(DefaultParameterSetName="GetRequests")]
    param (
        [Parameter(Mandatory)]
        [string]$uri,

        [Parameter(Mandatory, ParameterSetName="GetRequests")]
        [Parameter(Mandatory, ParameterSetName="GetRequestById")]
        [string]$token,

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

Export-ModuleMember -Function Get-AcceloUri,Connect-Accelo,Invoke-Accelo,*-AcceloToken,*-AcceloRequest*,*-AcceloCompan*,*-AcceloAffiliation*