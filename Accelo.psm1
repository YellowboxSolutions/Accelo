
function Invoke-Accelo{
    [Cmdletbinding(DefaultParameterSetName="InvokeUriString")]
    param (
        [Parameter(Mandatory=$true,ParameterSetName="InvokeUriString")]
        [string]$uri,

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
        $newuri = [System.UriBuilder]$uri
        $newuri.Query = $queryCollection.ToString()

        $invokeSplat = @{
            method = $method
            headers = $headers
            uri = $newuri.Uri.OriginalString
        }
        if ($body) {
            $invokeSplat.add('Body', $body)
        }
        write-verbose "Invocation: uri($uri)"
        write-verbose "Invocation: method($method)"
        write-verbose "Invocation: query($($query|convertto-json))"
        write-verbose "Invocation: headers($($headers|convertto-json))"
        write-verbose "Invocation: body($($body|convertto-json))"
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
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true)]
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

function Get-AcceloCompanies {
    [Cmdletbinding(DefaultParameterSetName="GetCompanies")]
    param(
        [Parameter(Mandatory=$true)]
        [string]$uri,
        [Parameter(Mandatory=$true,ParameterSetName="GetCompanies")]
        [Parameter(Mandatory=$true,ParameterSetName="GetCompanyById")]
        [string]$token,

        [Parameter(Mandatory=$true,ParameterSetName="GetCompanyById")]
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
            "Content-Type" = "application/json"
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
        [Parameter(mandatory=$true)]
        [string]$uri,

        [Parameter(Mandatory=$true, ParameterSetName="GetRequests")]
        [Parameter(Mandatory=$true, ParameterSetName="GetRequestById")]
        [string]$token,

        [Parameter(Mandatory=$true, ParameterSetName="GetRequestById")]
        [string]$requestId,

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
                $uriObject.path = "$($uriObject.path)/requests/$requestId"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $headers = @{
            "Content-Type" = "application/json"
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
        [Parameter(Mandatory=$true)]
        [string]$uri,

        [Parameter(Mandatory=$true, ParameterSetName="AddRequest")]
        [string]$token,

        [Parameter(Mandatory=$true, ParameterSetName="AddRequest")]
        [string]$typeId,

        [Parameter(Mandatory=$true, ParameterSetName="AddRequest")]
        [string]$title

    )
    
    begin {
        $uriObject = [System.Uribuilder]$uri
        $uriObject.path = "$($uriObject.path)/requests"
        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $token"
        }
    }
    
    process {
        $acceloRequest = @{
            type_id = "4"
            body = "Test Subject"
            title = "Test Title"
            affiliation = "88"
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
        [Parameter(Mandatory=$true)]
        [string]$uri,

        [Parameter(Mandatory=$true,ParameterSetName="GetAffiliations")]
        [Parameter(Mandatory=$true,ParameterSetName="GetAffiliationsById")]
        [string]$token,

        [Parameter(Mandatory=$true,ParameterSetName="GetAffiliationsById")]
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
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $token"
        }
    }


    Process {
        $affiliations = (Invoke-Accelo -uri $uriObject -headers $headers -query $query).response
        $affiliations
    }
}

Export-ModuleMember -Function Invoke-Accelo,*-AcceloToken,*-AcceloRequest*,*-AcceloCompan*,*-AcceloAffiliation*