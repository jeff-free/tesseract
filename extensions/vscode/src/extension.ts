import * as vscode from 'vscode';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
  // 1. 註冊一鍵套用指令 (由 Chat 內互動按鈕或連結點擊觸發)
  const applyDisposable = vscode.commands.registerCommand(
    'tesseract.applyHyperfold',
    async (payload?: any) => {
      vscode.window.showInformationMessage('⬡ Tesseract: 已確認套用超維摺疊！正在寫入知識庫...');

      const allCommands = await vscode.commands.getCommands(true);

      // 若在 Antigravity IDE 中，通知 Agent 完成 MCP 寫入
      if (allCommands.includes('antigravity.sendPromptToAgentPanel')) {
        await vscode.commands.executeCommand(
          'antigravity.sendPromptToAgentPanel',
          '使用者已點擊 [⬡ 一鍵套用摺疊] 確認套用！請立即調用 `tesseract_hyperfold` 工具將規則與維度鏈結寫入 iCloud Vault。'
        );
      }
    }
  );
  context.subscriptions.push(applyDisposable);

  // 2. 註冊取消指令
  const discardDisposable = vscode.commands.registerCommand(
    'tesseract.discardHyperfold',
    async () => {
      vscode.window.showInformationMessage('已取消本次超維摺疊變更。');
    }
  );
  context.subscriptions.push(discardDisposable);

  // 3. 註冊核心觸發指令：tesseract.hyperfold (由編輯器按鈕或快捷鍵觸發)
  const hyperfoldDisposable = vscode.commands.registerCommand(
    'tesseract.hyperfold',
    async (uri?: vscode.Uri) => {
      let targetUri = uri;
      const editor = vscode.window.activeTextEditor;

      if (!targetUri && editor) {
        targetUri = editor.document.uri;
      }

      if (!targetUri) {
        vscode.window.showWarningMessage('請先開啟一篇 Markdown 筆記再執行 Tesseract Hyperfold。');
        return;
      }

      const filePath = targetUri.fsPath;
      const fileName = path.basename(filePath);

      // 取得工作區相對路徑（若可用）
      const workspaceFolder = vscode.workspace.getWorkspaceFolder(targetUri);
      const relativePath = workspaceFolder
        ? path.relative(workspaceFolder.uri.fsPath, filePath)
        : fileName;

      const allCommands = await vscode.commands.getCommands(true);

      // A. Antigravity IDE 原生靜默觸發 (直接派送 Agent 任務，不碰剪貼簿！)
      if (allCommands.includes('antigravity.sendPromptToAgentPanel')) {
        try {
          if (allCommands.includes('antigravity.openChatView')) {
            await vscode.commands.executeCommand('antigravity.openChatView');
          }

          const promptText = `請調用 tesseract-hyperfold skill 對「${relativePath}」進行超維摺疊 (Hyperfold) 認知審查。請以 Plan Review 形式呈現提煉的規範與維度鏈結，等待使用者確認套用。`;

          await vscode.commands.executeCommand('antigravity.sendPromptToAgentPanel', promptText);
          return;
        } catch (err) {
          console.warn('Failed to dispatch via antigravity.sendPromptToAgentPanel:', err);
        }
      }

      // B. VS Code 原生 Chat 觸發
      if (allCommands.includes('workbench.action.chat.open')) {
        try {
          await vscode.commands.executeCommand('workbench.action.chat.open', {
            query: `@tesseract /hyperfold "${relativePath}"`
          });
          return;
        } catch (err) {
          console.warn('Failed to open workbench chat:', err);
        }
      }

      vscode.window.showInformationMessage(`⬡ Tesseract Hyperfold 已鎖定筆記：${relativePath}`);
    }
  );
  context.subscriptions.push(hyperfoldDisposable);

  // 4. 註冊 Chat 參與者 (@tesseract)
  if (typeof vscode.chat?.createChatParticipant === 'function') {
    const participant = vscode.chat.createChatParticipant(
      'tesseract.agent',
      async (
        request: vscode.ChatRequest,
        chatContext: vscode.ChatContext,
        stream: vscode.ChatResponseStream,
        token: vscode.CancellationToken
      ) => {
        stream.progress('⬡ 正在分析筆記內容並調用 Tesseract Hyperfold Skill...');

        const userPrompt = request.prompt.trim();

        // 構建引導模型以 Plan Review 形式輸出的系統提示
        const systemPrompt = [
          '你是 Tesseract 4D 知識庫的超維摺疊 (Hyperfold) 代理。',
          '請執行以下認知審查 SOP：',
          '1. 提煉規範：從修改中萃取 1 條可泛化工程習慣，註明寫入專案 `tesseract/rule.md` 或全域 `_global/rule.md`。',
          '2. 維度織網：提出 1~3 個最相關的知識庫雙向鏈結建議（`[[topic-name]]`）。',
          '3. 索引摘要：提供更新至 index.md Changelog 的簡短摘要。',
          '4. 呈現風格：使用清晰的 Plan Review 卡片（包含 Checkbox 清單）。',
          '5. 結尾必須提供可點擊的互動按鈕。'
        ].join('\n');

        try {
          // 若有可用的 VS Code Language Model API (如 GitHub Copilot)
          if (typeof vscode.lm?.selectChatModels === 'function') {
            const models = await vscode.lm.selectChatModels({ family: 'gpt-4o' });
            const model = models[0] || (await vscode.lm.selectChatModels())[0];

            if (model) {
              const messages = [
                vscode.LanguageModelChatMessage.User(systemPrompt),
                vscode.LanguageModelChatMessage.User(
                  userPrompt || '請針對當前筆記執行超維摺疊 (Hyperfold) 認知審查。'
                )
              ];

              const response = await model.sendRequest(messages, {}, token);
              for await (const chunk of response.text) {
                stream.markdown(chunk);
              }
            }
          } else {
            // Fallback: 輸出標準 Plan Review 審查卡
            stream.markdown(`### ⬡ Tesseract Hyperfold (超維摺疊) 認知審查\n\n`);
            stream.markdown(`已接收到對 **${userPrompt || '當前筆記'}** 的摺疊請求。\n\n`);
            stream.markdown(`#### 1. ✦ 提煉規範建議 (rule.md)\n- [ ] 檢視並提煉本次修改中的架構約束或編碼慣例。\n\n`);
            stream.markdown(`#### 2. ✦ 維度織網 ([[wikilinks]])\n- [ ] 尋找並補充與此筆記關聯的知識節點。\n\n`);
            stream.markdown(`#### 3. ✦ 索引拓撲更新 (index.md)\n- [ ] 記錄變更至知識庫 Changelog。\n\n`);
          }

          // VS Code Chat 原生實體按鈕 (不使用易誤判的 Markdown 假連結)
          if (typeof stream.button === 'function') {
            stream.button({
              title: '⬡ 一鍵套用摺疊 (Apply Hyperfold)',
              command: 'tesseract.applyHyperfold'
            });
            stream.button({
              title: '✕ 放棄變更 (Discard)',
              command: 'tesseract.discardHyperfold'
            });
          }
        } catch (error: any) {
          stream.markdown(`⚠ Hyperfold 執行過程中發生問題：${error?.message || error}`);
        }
      }
    );

    participant.iconPath = new vscode.ThemeIcon('symbol-namespace');
    context.subscriptions.push(participant);
  }
}

export function deactivate() {}
