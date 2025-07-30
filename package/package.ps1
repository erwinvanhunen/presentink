param (
    [string]$AppName = "./PresentInk.app",
    [ValidateSet("All", "ZIP", "DMG")]
    [string]$Format = "All"
    )


$contents = Get-Content -Path "$AppName/Contents/Info.plist" -Raw
$xml = [xml]$contents
$version = select-xml -Xml $xml -XPath "//key[.='CFBundleShortVersionString']/following-sibling::string[1]"
if ($version) {
    $versionValue = $version.Node.InnerText
    Write-Output "Version: $versionValue"
    $dmgFile = "PresentInk-$versionValue.dmg"
    $zipFile = "PresentInk-$versionValue.zip"
    
    # Create DMG file if Format is "All" or "DMG"
    if ($Format -eq "All" -or $Format -eq "DMG") {
        if(Get-ChildItem $dmgFile -ErrorAction SilentlyContinue) {
            Write-Host "Removing existing DMG file: $dmgFile" -ForegroundColor Yellow
            Remove-Item $dmgFile -Force
        }
        Write-Host "Creating DMG file: $dmgFile" -ForegroundColor Cyan
        create-dmg --volname "PresentInk $versionValue" `
            --background "background@2x.png" `
            --volicon "$AppName/Contents/Resources/AppIcon.icns" `
            --eula license.rtf `
            --window-pos 200 120 `
            --window-size 800 400 `
            --icon-size 100 `
            --icon "PresentInk.app" 200 190 `
            --app-drop-link 600 190 `
            --codesign $env:APPLE_SIGNING_IDENTITY `
            --notarize "PRESENTINK"`
            $dmgFile `
            $AppName
    }
    
    # Create ZIP file if Format is "All" or "ZIP"
    if ($Format -eq "All" -or $Format -eq "ZIP") {
        if(Get-ChildItem $zipFile -ErrorAction SilentlyContinue) {
            Write-Host "Removing existing ZIP file: $zipFile" -ForegroundColor Yellow
            Remove-Item $zipFile -Force
        }
        Write-Host "Creating ZIP file: $zipFile" -ForegroundColor Cyan
        Write-Host "Creating folder structure for ZIP file" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path "PresentInk" -Force | Out-Null
        Copy-Item -Path $AppName -Destination "PresentInk" -Recurse
        Copy-Item -Path "license.rtf" -Destination "PresentInk" -Force
       #zip -r $zipFile $AppName license.rtf -x "*.DS_Store" -x "__MACOSX/*"
        ditto -c -k -X --rsrc PresentInk $zipFile
        Remove-Item -Path "PresentInk" -Recurse -Force
    }
}
