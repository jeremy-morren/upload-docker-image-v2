param(
    [Parameter(Mandatory)][Uri]$Remote, 
    [Parameter(Mandatory)]$Archive
)

function GetUrl {
    param([Parameter(Mandatory)][string]$relativeUrl)
    [Uri]::new($Remote, $relativeUrl).ToString()
}

function GetDigest {
    param([Parameter(Mandatory)][string]$file)
    "sha256:$((sha256sum $file).Split(" ")[0])"
}

function UploadLayer {
    param(
        [Parameter(Mandatory)][string]$repository, 
        [Parameter(Mandatory)][string]$layer
    )

    #First check to see if layer already uploaded
    
    # Send Head request to /v1/<repo>/blobs/<digest>
    # If response code is 200 then layer already uploaded
    
    $digest = GetDigest $layer

    $resp = Invoke-WebRequest -Method Head (GetUrl("v2/$repository/blobs/$digest")) -SkipHttpErrorCheck
    if ($resp.StatusCode -eq 200) {
        Write-Host "Layer $layer already exists, skipping" -ForegroundColor DarkGray
        return
    }

    #Get BLOB location
    $resp = Invoke-WebRequest -Method 'Post' `
        -Uri (GetUrl("v2/$repository/blobs/uploads/"))
    $loc = $resp.Headers["Location"][0].Trim()
    
    $resp = Invoke-WebRequest (GetUrl($loc)) -Method 'Patch' `
        -InFile $layer -ContentType application/octet-stream
    $loc = $resp.Headers["Location"][0].Trim()
    
    #Mark as complete
    Invoke-WebRequest (GetUrl("$loc&digest=$digest")) -Method 'Put' | Out-Null
    
    Write-Host "Uploaded layer $layer" -ForegroundColor Darkgray
}

function UploadManifest {
    param(
        [Parameter(Mandatory)]$manifest,
        [Parameter(Mandatory)][string]$repository,
        [Parameter(Mandatory)][string]$version
    )

    $manifestJson = @{
        schemaVersion = 2
        mediaType = "application/vnd.docker.distribution.manifest.v2+json"
        config = @{
            mediaType = "application/vnd.docker.container.image.v1+json"
            size = (Get-Item $manifest.Config).Length
            digest = GetDigest $manifest.Config
        }
        layers = @()
    }

    foreach ($layer in $manifest.Layers) {
        $manifestJson.layers += @{
            mediaType = "application/vnd.docker.image.rootfs.diff.tar.gzip"
            size = (Get-Item $layer).Length
            digest = GetDigest $layer
        }
    }

    $resp = Invoke-WebRequest (GetUrl("v2/$repo/manifests/$version")) `
        -Method 'Put' -ContentType $manifestJson.mediaType `
        -Body (ConvertTo-Json $manifestJson -Depth 50)
    
    $loc = $resp.Headers["Location"][0].Trim()

    Write-Host "Uploaded $($repository):$($version) manifest" -ForegroundColor DarkGray
}

function UploadRepository {
    param([Parameter(Mandatory)]$manifest)

    $repo = $manifest.RepoTags[0].Split(":")[0]
    Write-Host "Uploading Repository $repo" -ForegroundColor DarkGray

    foreach ($layer in $manifest.Layers) {
        UploadLayer -Repository $repo -Layer $layer
    }

    UploadLayer -Repository $repo -Layer $manifest.Config

    foreach ($tag in $manifest.RepoTags) {
        UploadManifest -Manifest $manifest -Repository $repo -Version $tag.Split(":")[1]
    }
    
    Write-Host "Successfully uploaded Repository $repo!" -ForegroundColor Cyan
}

$tmp="/tmp/image-upload"

try {
    Push-Location

    $Archive=Join-Path (Get-Location) $Archive
    if (Test-Path $tmp) {
        Remove-Item $tmp -Recurse
    }
    New-Item $tmp -Type Directory | Out-Null

    Set-Location $tmp
    tar xf $Archive

    ConvertFrom-Json (Get-Content manifest.json) | % { UploadRepository -Manifest $_ }

    Write-Host "Complete!" -ForegroundColor Cyan
}
finally {
    Pop-Location 
    if (Test-Path $tmp) {
        Remove-Item $tmp -Recurse
    }  
}
 