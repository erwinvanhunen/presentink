param (
    [string]$AppName = "./PresentInk.app"
    )


$contents = Get-Content -Path "$AppName/Contents/Info.plist" -Raw
$xml = [xml]$contents
$version = select-xml -Xml $xml -XPath "//key[.='CFBundleShortVersionString']/following-sibling::string[1]"
if ($version) {
    $versionValue = $version.Node.InnerText
    Write-Output "Version: $versionValue"
    $dmgFile = "PresentInk-$versionValue.dmg"
    $zipFile = "PresentInk-$versionValue.zip"
    if(Get-ChildItem $dmgFile -ErrorAction SilentlyContinue) {
        Write-Output "Removing existing DMG file: $dmgFile"
        Remove-Item $dmgFile -Force
    }
    Write-Output "Creating DMG file: $dmgFile"
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
    if(Get-ChildItem $zipFile -ErrorAction SilentlyContinue) {
        Write-Output "Removing existing ZIP file: $zipFile"
        Remove-Item $zipFile -Force
    }
    Write-Output "Creating ZIP file: $zipFile"
    zip -r $zipFile $AppName -x "*.DS_Store" -x "__MACOSX/*"
}
