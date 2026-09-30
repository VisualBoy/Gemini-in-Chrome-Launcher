@echo off
taskkill /F /IM chrome.exe /T 2>nul
timeout /t 2 /nobreak >nul

start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --variations-override-country=us ^
  --lang=en-US ^
  --enable-features=Glic,GlicSidePanel,GlicActor,GlicUnifiedFreScreen,GlicEntrypointVariations,GlicActorAutofill,GlicActorCursor,GlicActorScriptTools,GlicCaptureRegion,GlicDefaultToLastActiveConversation,GlicExperimentalTriggering,GlicPdfSummarize,GlicSelectionPrompt,GlicTabGroups,GlicZeroStateSuggestions,SyncAiThreads,SyncGeminiThreads,ContextualTasksSidePanel,PromptAPI,PromptAPIMultimodalInput,SummarizerAPI,WriterAPI,RewriterAPI,ProofreaderAPI ^
  --disable-session-crashed-bubble
