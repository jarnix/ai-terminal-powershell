> Type `#` in your PowerShell prompt, ask anything, and let an LLM answer it — or hand you a ready-to-run command.
![Platform](https://img.shields.io/badge/platform-Windows-blue)
![Shell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)
HashPrompt is a single PowerShell script that hooks the Enter key in your shell. Any line that starts with `#` is sent to an LLM instead of being executed. The model decides what you wanted:
A question? It prints the answer inline.
A task? It shows you a command, and nothing runs until you confirm.
```text
PS C:\> # what's taking up the most space in this folder

  Get-ChildItem -Recurse | Sort-Object Length -Descending | Select-Object -First 5 FullName, @{N='MB';E={[math]::Round($_.Length/1MB,1)}}
  Lists the 5 largest files by size in MB
  Run? [y]es / [c]opy / [N]o: y

PS C:\> # explain the difference between a junction and a symlink

  A junction (mklink /J) only works for directories and is resolved on the
  local machine, while a symbolic link (mklink) works for files or folders
  and can point across volumes or to network paths...
```
Why a script and not a "terminal plugin"?
Windows Terminal can't do this on its own — it's only an emulator that draws whatever shell runs inside it. Its extension API (fragments) adds profiles, themes, and settings, but it has no hook for intercepting what you type. That logic belongs in the shell. HashPrompt uses PSReadLine to override the Enter key: it reads the input buffer before PowerShell parses it, and reroutes any `#`-prefixed line to the model. (As a bonus, PowerShell normally treats `#` as a comment — but because the hook fires before parsing, the line never reaches the comment logic.)
Features
Two modes, auto-detected — the model returns structured JSON saying whether it's an answer or a command, so you don't have to flag your intent.
Confirmation gate — AI-suggested commands are shown first; `y` runs, `c` copies to clipboard, anything else cancels.
Non-intrusive — normal commands behave exactly as before; multi-line editing is preserved via `ValidateAndAcceptLine`.
Provider-agnostic — ships with Anthropic's Claude, but a few lines swap it for OpenAI or a local Ollama model.
One file, no dependencies beyond what already ships with PowerShell 7.
Requirements
Windows with Windows Terminal (or any host running PowerShell)
PowerShell 7+ recommended (`pwsh`). Windows PowerShell 5.1 works but is less tested.
The PSReadLine module (bundled with PowerShell 7)
An Anthropic API key — or an OpenAI key / local Ollama install if you swap providers
Installation
Download `ai-terminal.ps1` to a stable location, e.g. `~\ai-terminal.ps1`.
Set your API key once (persists across sessions):
```powershell
   setx ANTHROPIC_API_KEY "sk-ant-..."
   ```
Open a new terminal afterward so the variable is picked up.
Load the script from your PowerShell profile:
```powershell
   notepad $PROFILE   # creates it if prompted
   ```
Add this line and save:
```powershell
   . "$HOME\ai-terminal.ps1"
   ```
Reload:
```powershell
   . $PROFILE
   ```
You're live — try `# how much free disk space do I have`.
Configuration
Edit the top of `ai-terminal.ps1`:
Setting	Default	Notes
`$script:AIModel`	`claude-haiku-4-5-20251001`	Haiku is fast and cheap, ideal for a terminal helper. Use `claude-sonnet-4-6` or `claude-opus-4-7` for harder reasoning.
`$script:AIApiKey`	`$env:ANTHROPIC_API_KEY`	Read from your environment by default.
Usage
You type	What happens
`# kill the process on port 3000`	Shows a `Stop-Process` command, waits for confirmation.
`# what does $? mean in PowerShell`	Prints an explanation inline.
`git status`	Runs normally — no `#`, no interception.
When a command is offered:
`y` — run it
`c` — copy it to the clipboard
anything else — do nothing
Using a different provider
The model call lives in one function (`Invoke-AILine`). To switch providers, change the endpoint, headers, and the line that extracts the response text:
OpenAI — POST to `https://api.openai.com/v1/chat/completions` with an `Authorization: Bearer <key>` header, and read `choices[0].message.content`.
Ollama (local) — POST to `http://localhost:11434/api/chat` with your model name, and read `message.content`. No API key needed.
The system prompt that instructs the model to reply in the `{"type": "...", "content": "..."}` JSON shape works unchanged across providers.
Safety
Letting an LLM run shell commands is the part that bites people, so HashPrompt never executes a suggested command without an explicit `y`. Even so:
Read commands before running them — models can be confidently wrong.
Be cautious with anything destructive (`Remove-Item`, `Stop-Process`, registry edits). The model is asked to flag risk in its note, but treat that as a hint, not a guarantee.
Your prompts are sent to a third-party API. Don't paste secrets after `#`.
Limitations
PowerShell only. If your default Windows Terminal profile is WSL (bash/zsh), this won't work as-is — bash also treats `#` as a comment and has no equally clean pre-parse keypress hook. A `command_not_found_handler` or a small `q "..."` function is the usual workaround there.
Latency. Every `#` line is a network round-trip; expect a short pause.
Windows PowerShell 5.1 may need TLS 1.2 forced (the script does this) and is less thoroughly tested than PowerShell 7.
Contributing
Issues and pull requests are welcome — provider adapters (a bash/zsh port, a clean OpenAI/Ollama switch), better command-safety heuristics, and streaming output are all good starting points.
License
MIT — do what you like, no warranty.
---
Not affiliated with Anthropic or Microsoft. "Claude" and "PowerShell" are trademarks of their respective owners.
