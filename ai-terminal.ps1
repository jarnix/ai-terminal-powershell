# ============================================================
#  ai-terminal.ps1  —  "#" prefix routes a line to an LLM
#  Works inside Windows Terminal's PowerShell profile.
#  Recommended: PowerShell 7+ (pwsh). Needs the PSReadLine module.
# ============================================================
 
# --- Config ---------------------------------------------------
$script:AIModel  = "claude-haiku-4-5-20251001"   # swap to "claude-sonnet-4-6" for harder reasoning
$script:AIApiKey = $env:ANTHROPIC_API_KEY        # set this in your environment (see setup notes)
 
# TLS for Windows PowerShell 5.1 (harmless on PS7)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
function Invoke-AILine {
    param([string]$Prompt)
 
    if (-not $script:AIApiKey) {
        Write-Host "ANTHROPIC_API_KEY is not set." -ForegroundColor Red
        return
    }
 
    $system = @"
You are a terminal assistant running in PowerShell on Windows.
The user typed a request that was prefixed with '#'. Decide whether they want:
  - a shell command to perform a task, OR
  - a direct answer / explanation.
Respond with ONLY a raw JSON object. No markdown, no code fences, no preamble.
Use exactly one of these shapes:
  {"type":"command","content":"<powershell command>","note":"<one short line: what it does / any risk>"}
  {"type":"answer","content":"<concise answer>"}
Prefer PowerShell-native commands. If a command is destructive, make that explicit in 'note'.
"@
 
    $body = @{
        model      = $script:AIModel
        max_tokens = 1024
        system     = $system
        messages   = @(@{ role = "user"; content = $Prompt })
    } | ConvertTo-Json -Depth 6
 
    try {
        $resp = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers @{
                "x-api-key"         = $script:AIApiKey
                "anthropic-version" = "2023-06-01"
                "content-type"      = "application/json"
            } `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
    }
    catch {
        Write-Host "AI request failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
 
    $text = ($resp.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
    if (-not $text) { Write-Host "Empty response." -ForegroundColor Red; return }
 
    # Strip accidental code fences just in case the model adds them
    $text = ($text -replace '(?s)^\s*```(?:json)?\s*', '') -replace '(?s)\s*```\s*$', ''
 
    try   { $obj = $text | ConvertFrom-Json }
    catch { Write-Host $text; return }   # not JSON -> just print it
 
    switch ($obj.type) {
        "answer" {
            Write-Host ""
            Write-Host $obj.content
            Write-Host ""
        }
        "command" {
            Write-Host ""
            Write-Host "  $($obj.content)" -ForegroundColor Cyan
            if ($obj.note) { Write-Host "  $($obj.note)" -ForegroundColor DarkGray }
            $ans = Read-Host "  Run? [y]es / [c]opy / [N]o"
            switch ($ans.ToLower()) {
                'y' { Write-Host ""; Invoke-Expression $obj.content }
                'c' { $obj.content | Set-Clipboard; Write-Host "  Copied to clipboard." -ForegroundColor Green }
                default { }
            }
            Write-Host ""
        }
        default { Write-Host $text }
    }
}
 
# --- Hook the Enter key --------------------------------------
# If the buffer starts with '#', rewrite it into a call to Invoke-AILine and
# accept it (so it runs in the normal command context, where Read-Host /
# Invoke-Expression behave correctly). Otherwise, fall back to the default
# behavior — ValidateAndAcceptLine preserves multi-line editing.
Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
 
    if ($line.TrimStart().StartsWith('#')) {
        $prompt = $line.TrimStart().Substring(1).Trim().Replace("'", "''")  # escape single quotes
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Invoke-AILine -Prompt '$prompt'")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
    else {
        [Microsoft.PowerShell.PSConsoleReadLine]::ValidateAndAcceptLine()
    }
}
