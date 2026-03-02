export default {
  async fetch(request, env) {
    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: corsHeaders(),
      });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Public pages (no auth required)
    if (path === "/privacy") {
      return htmlResponse(privacyPolicyHTML());
    }
    if (path === "/terms") {
      return htmlResponse(termsOfServiceHTML());
    }

    // Verify app token
    const appToken = request.headers.get("X-App-Token");
    if (!appToken || appToken !== env.APP_AUTH_TOKEN) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    try {
      // OpenAI proxy
      if (path.startsWith("/openai/")) {
        return await proxyOpenAI(request, env, path);
      }

      // AssemblyAI proxy
      if (path.startsWith("/assemblyai/")) {
        return await proxyAssemblyAI(request, env, path);
      }

      return jsonResponse({ error: "Not found" }, 404);
    } catch (err) {
      return jsonResponse({ error: err.message }, 500);
    }
  },
};

// --- OpenAI Proxy ---

async function proxyOpenAI(request, env, path) {
  // /openai/v1/chat/completions -> api.openai.com/v1/chat/completions
  const targetPath = path.replace("/openai", "");
  const targetURL = `https://api.openai.com${targetPath}`;

  const headers = new Headers();
  headers.set("Authorization", `Bearer ${env.OPENAI_API_KEY}`);
  headers.set("Content-Type", request.headers.get("Content-Type") || "application/json");

  const response = await fetch(targetURL, {
    method: request.method,
    headers,
    body: request.body,
  });

  return new Response(response.body, {
    status: response.status,
    headers: {
      ...Object.fromEntries(response.headers),
      ...corsHeaders(),
    },
  });
}

// --- AssemblyAI Proxy ---

async function proxyAssemblyAI(request, env, path) {
  // /assemblyai/upload       -> api.assemblyai.com/v2/upload
  // /assemblyai/transcript   -> api.assemblyai.com/v2/transcript
  // /assemblyai/transcript/X -> api.assemblyai.com/v2/transcript/X
  const subPath = path.replace("/assemblyai", "");
  const targetURL = `https://api.assemblyai.com/v2${subPath}`;

  const headers = new Headers();
  headers.set("authorization", env.ASSEMBLYAI_API_KEY);

  const contentType = request.headers.get("Content-Type");
  if (contentType) {
    headers.set("Content-Type", contentType);
  }

  const response = await fetch(targetURL, {
    method: request.method,
    headers,
    body: request.method !== "GET" ? request.body : undefined,
  });

  return new Response(response.body, {
    status: response.status,
    headers: {
      ...Object.fromEntries(response.headers),
      ...corsHeaders(),
    },
  });
}

// --- Helpers ---

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Token",
  };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(),
    },
  });
}

function htmlResponse(html) {
  return new Response(html, {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

// --- Legal Pages ---

function pageWrapper(title, content) {
  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${title} - PodNote</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 680px; margin: 0 auto; padding: 24px 16px; background: #111; color: #e0e0e0; line-height: 1.7; }
  h1 { color: #fff; font-size: 1.8em; margin-bottom: 4px; }
  h2 { color: #fff; font-size: 1.2em; margin-top: 28px; }
  p, li { color: #bbb; font-size: 0.95em; }
  .date { color: #888; font-size: 0.85em; margin-bottom: 32px; }
  ul { padding-left: 20px; }
  a { color: #ef4444; }
</style>
</head>
<body>
<h1>${title}</h1>
${content}
</body>
</html>`;
}

function privacyPolicyHTML() {
  return pageWrapper("隐私政策", `
<p class="date">最后更新日期：2026年3月1日</p>

<h2>1. 数据收集与存储</h2>
<p>PodNote 重视您的隐私。您的录音文件完全存储在您的设备本地，我们不会上传或保存您的录音文件到我们的服务器。</p>
<p>我们不要求您创建账户，也不收集个人身份信息。</p>

<h2>2. 第三方服务</h2>
<p>当您使用 AI 功能（语音转写、摘要生成、AI 对话）时，您的音频或文本数据会被发送到以下第三方服务进行处理：</p>
<ul>
  <li>OpenAI — 用于文本润色、摘要生成、AI 对话</li>
  <li>AssemblyAI — 用于语音转写</li>
</ul>
<p>这些服务按照各自的隐私政策处理数据。我们建议您查阅相关政策以了解详情。</p>

<h2>3. 订阅信息</h2>
<p>订阅通过 Apple 的 App Store 管理。我们不会收集或存储您的支付信息。所有交易由 Apple 处理。</p>

<h2>4. 数据安全</h2>
<p>您的录音数据存储在设备本地，受到 iOS 系统级别的安全保护。通过代理服务器传输的数据使用 HTTPS 加密。</p>

<h2>5. 儿童隐私</h2>
<p>本应用不面向 13 岁以下的儿童。我们不会有意收集 13 岁以下儿童的个人信息。</p>

<h2>6. 政策变更</h2>
<p>我们可能会不时更新本隐私政策。更新后的政策将在应用内发布，继续使用本应用即表示您同意更新后的政策。</p>

<h2>7. 联系我们</h2>
<p>如果您对本隐私政策有任何疑问，请通过应用内的反馈功能联系我们。</p>
`);
}

function termsOfServiceHTML() {
  return pageWrapper("使用条款", `
<p class="date">最后更新日期：2026年3月1日</p>

<h2>1. 服务描述</h2>
<p>PodNote 是一款 AI 语音备忘录应用，提供录音、语音转写、智能摘要和 AI 对话功能。部分功能需要订阅 PodNote Pro。</p>

<h2>2. 订阅条款</h2>
<ul>
  <li>订阅通过您的 Apple ID 账户进行购买</li>
  <li>订阅期结束前 24 小时内会自动续费，除非您在此之前关闭自动续费</li>
  <li>您可以在 iPhone 的"设置" &gt; "Apple ID" &gt; "订阅"中管理或取消订阅</li>
  <li>取消订阅后，您仍可使用已付费期间的服务直至到期</li>
  <li>免费试用期（如有）未使用的部分在购买订阅后将失效</li>
</ul>

<h2>3. 免费试用</h2>
<p>免费用户可无限录音和播放。首次使用 AI 功能时，该条录音将被标记为试用录音，可无限使用所有 AI 功能。其他录音的 AI 功能需要订阅 PodNote Pro。</p>

<h2>4. AI 生成内容</h2>
<p>AI 生成的转写文本、摘要和对话回复仅供参考。我们不对 AI 生成内容的准确性、完整性或适用性做任何保证。</p>
<p>您不应将 AI 生成的内容作为专业建议（包括但不限于法律、医疗、财务建议）的替代。</p>

<h2>5. 用户责任</h2>
<ul>
  <li>您有责任确保录音内容符合当地法律法规</li>
  <li>录音他人前请确保已获得相关方的同意</li>
  <li>请勿使用本应用进行任何违法活动</li>
</ul>

<h2>6. 免责声明</h2>
<p>本应用按"现状"提供，不提供任何明示或暗示的保证。我们不对因使用本应用而导致的任何直接或间接损失承担责任。</p>

<h2>7. 条款变更</h2>
<p>我们保留随时修改本使用条款的权利。修改后的条款将在应用内发布，继续使用本应用即表示您同意修改后的条款。</p>
`);
}
