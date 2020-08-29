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
        [string]$fields,
        [string]$search
    )
    
    begin {
    }
    
    process {
        $UriBuilder = [UriBuilder]$uri

        if (($filters) -or ($fields) -or ($limit) -or ($search)) {
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
            if ($search) {
                $queryCollection.add("_search", $search)
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

        [string]$ContentType,

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
        if ($ContentType) {
            $invokeSplat.add('ContentType', $ContentType)
            if (($body) -and ($ContentType -eq "application/x-www-form-urlencoded")) {
                foreach ($key in $body) {
                    $newbody = "$newbody$key = $($body[$key])`r`n"
                }

            }
        }
        
        if (($headers) -and ($headers.ContainsKey('Authorization'))) {
            $invokeSplat.add('headers', $headers)
        } elseif ($AcceloSession.AccessToken) {
            $invokeSplat.add('headers', @{Authorization = "Bearer $($AcceloSession.AccessToken)"})
        } else {
            Throw "No Auth info provided"
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
        write-verbose "Request: $($invokeSplat|convertto-json)"
        write-verbose "Response: $invocation"
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
    param (
        # Company Id
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetCompanyById")]
        [string]
        $Id,

        [Parameter(ParametersetName="GetCompany")]
        [int]$limit,

        [Parameter(ParametersetName="GetCompany")]
        [string]$filters,

        [Parameter()]
        [string]$fields,

        [Parameter(ParameterSetName="GetCompany")]
        [string]$search
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

        $UriSplat = @{
            Uri = $AcceloSession.BaseUri
            Path = $UriPath
            Limit = $limit
            Filters = $filters
            Fields = $Fields
            Search = $Search
        }
        
        $Uri = Get-AcceloUri @UriSplat
        $company = (Invoke-Accelo -uri $uri).response
        $company
    }
}

function Get-AcceloRequest {
    [CmdletBinding(DefaultParameterSetName="GetRequest")]
    param (

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetRequestById")]
        [string]$Id,

        [Parameter(ParameterSetName="GetRequest")]
        [int]$limit,

        [Parameter(ParameterSetName="GetRequest")]
        [string]$filters,

        [Parameter()]
        [string]$fields,

        [Parameter(ParameterSetName="GetRequest")]
        [string]$search
    )
    
    begin {
        
    }
    
    process {
        $UriPath = $null
        switch ($PSCmdlet.parametersetname) {
            'GetRequest' { 
                $UriPath = "api/v0/requests"
            }

            'GetRequestById' {
                $UriPath = "/api/v0/requests/$Id"
            }

            Default {
                throw "Something went wrong with the ParameterSetName."
            }
        }
        $UriSplat = @{
            Uri = $AcceloSession.BaseUri
            Path = $UriPath
            Limit = $limit
            Filters = $filters
            Fields = $Fields
            Search = $Search
        }
        
        $Uri = Get-AcceloUri @UriSplat
        
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
        $UriPath = "/api/v0/requests"
        $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
    }
    
    process {
        $acceloRequest = @{
            type_id = $typeId
            title = $title
            body = $body
            affiliation_id = $affiliationId
        }

        $request = (Invoke-Accelo -uri $Uri -method "POST" -body $acceloRequest).response
        $request
    }
    
    end {
        
    }
}

function Update-AcceloRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$Id,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Title,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Body,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$TypeId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$LeadId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$AffiliationId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$PriorityId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Source,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet("pending","open","converted","closed")]
        [string]$Standing,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$ClaimerId,

        [Parameter()]
        [string]$filters,

        [Parameter()]
        [string]$fields
    )
    $UriPath = "api/v0/requests/$Id"
    $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -fields $fields -filters $filters

    $RequestSplat = @{}

    if ($Title) { 
        $RequestSplat.add("title", $Title)
    }

    if ($Body) { 
        $RequestSplat.add("body", $Body)
    }

    if ($TypeId) { 
        $RequestSplat.add("type_id", $TypeId)
    }
    
    if ($LeadId) { 
        $RequestSplat.add("lead_id", $LeadId)
    }
    
    if ($AffiliationId) { 
        $RequestSplat.add("affiliation_id", $AffiliationId)
    }
    
    if ($PriorityId) { 
        $RequestSplat.add("priority_id", $PriorityId)
    }
    
    if ($Source) { 
        $RequestSplat.add("source", $Source)
    }
    
    if ($Standing) { 
        $RequestSplat.add("standing", $Standing)
    }
    
    if ($ClaimerId) { 
        $RequestSplat.add("claimer_id", $ClaimerId)
    }
    $response = (Invoke-Accelo -uri $Uri -method "PUT" -contenttype "application/x-www-form-urlencoded" -body $RequestSplat).response
    $response
}

function Get-AcceloAffiliation {
    [Cmdletbinding(DefaultParameterSetName="GetAffiliation")]
    param (

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName="GetAffiliationById")]
        [string]$Id,
        
        [Parameter(ParameterSetName="GetAffiliation")]
        [int]$limit,

        [Parameter(ParameterSetName="GetAffiliation")]
        [string]$filters,

        [Parameter()]
        [string]$fields,

        [Parameter(ParameterSetName="GetAffiliation")]
        [string]$search
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

        $UriSplat = @{
            Uri = $AcceloSession.BaseUri
            Path = $UriPath
            Limit = $limit
            Filters = $filters
            Fields = $Fields
            Search = $Search
        }
        
        $Uri = Get-AcceloUri @UriSplat
        $affiliations = (Invoke-Accelo -uri $Uri).response
        $affiliations
    }
}

function Get-AcceloRequestType {
    [Cmdletbinding()]

    $UriPath = "/api/v0/requests/types"
    $Uri = Get-AcceloUri -Uri $AcceloSession.BaseUri -path $UriPath -limit $limit -filters $filters -fields $fields
    $RequestTypes = (Invoke-Accelo -uri $Uri).response.request_types
    $RequestTypes
}
Export-ModuleMember -Function Get-AcceloUri,Connect-Accelo,Invoke-Accelo,*-AcceloToken,*-AcceloRequest*,*-AcceloCompan*,*-AcceloAffiliation*,Get-AcceloSession