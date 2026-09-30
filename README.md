# Gemini-in-Chrome-Launcher

Launches Google Chrome configured with US country overrides and specific AI flags to enable AI features outside US, using a standard Windows Desktop Shortcut or `.bat` file without calling PowerShell script.

<img width="1024" height="576" alt="image" src="https://github.com/user-attachments/assets/cf29857d-17b4-4f96-9777-c0149643c3d1" />




## Chrome Experimental Flags Launcher

Launches Google Chrome configured with US country overrides, language forcing (`en-US`), and enabled feature flags for Glic, Prompt API, Summarizer API, Writer API, and related AI tools.

### Option 1: Desktop Shortcut / Program Link

Create a standard Windows shortcut pointing to `chrome.exe` with arguments passed via the Target field.

1. Right-click your desktop $\rightarrow$ **New** $\rightarrow$ **Shortcut**.
2. Set the **Target** field to:

```cmd
"C:\Program Files\Google\Chrome\Application\chrome.exe" --variations-override-country=us --lang=en-US --enable-features=Glic,GlicSidePanel,GlicActor,GlicUnifiedFreScreen,GlicEntrypointVariations,GlicActorAutofill,GlicActorCursor,GlicActorScriptTools,GlicCaptureRegion,GlicDefaultToLastActiveConversation,GlicExperimentalTriggering,GlicPdfSummarize,GlicSelectionPrompt,GlicTabGroups,GlicZeroStateSuggestions,SyncAiThreads,SyncGeminiThreads,ContextualTasksSidePanel,PromptAPI,PromptAPIMultimodalInput,SummarizerAPI,WriterAPI,RewriterAPI,ProofreaderAPI --disable-session-crashed-bubble

```

---

### Option 2: `.bat` Script

If you want a [batch file](https://github.com/VisualBoy/Gemini-in-Chrome-Launcher/tree/main/launch_chrome_ai.bat) that also kills active Chrome instances first:

`launch_chrome_ai.bat`

```bat
@echo off
taskkill /F /IM chrome.exe /T 2>nul
timeout /t 2 /nobreak >nul

start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --variations-override-country=us ^
  --lang=en-US ^
  --enable-features=Glic,GlicSidePanel,GlicActor,GlicUnifiedFreScreen,GlicEntrypointVariations,GlicActorAutofill,GlicActorCursor,GlicActorScriptTools,GlicCaptureRegion,GlicDefaultToLastActiveConversation,GlicExperimentalTriggering,GlicPdfSummarize,GlicSelectionPrompt,GlicTabGroups,GlicZeroStateSuggestions,SyncAiThreads,SyncGeminiThreads,ContextualTasksSidePanel,PromptAPI,PromptAPIMultimodalInput,SummarizerAPI,WriterAPI,RewriterAPI,ProofreaderAPI ^
  --disable-session-crashed-bubble

```

---

### Option 3: `.bat` Wrapper for the Full PowerShell Script with VPN orchestration

If you want a double-clickable `.bat` file that executes the full [PowerShell script](https://github.com/VisualBoy/Gemini-in-Chrome-Launcher/tree/main/launch_chrome_ai.ps1) (including elevated routing and VPN logic) while handling UAC elevation automatically:

`launch_chrome_ai_with_vpn.bat`

```bat
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0launch_chrome_ai.ps1\"' -Verb RunAs"

```
