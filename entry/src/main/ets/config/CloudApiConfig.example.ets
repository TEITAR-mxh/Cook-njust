/**
 * 百度 AI 开放平台密钥配置（模板）
 *
 * 使用方式：
 *   1. 复制本文件为同目录下的 CloudApiConfig.ets（该文件已被 .gitignore 忽略，不会提交）。
 *   2. 在 https://console.bce.baidu.com 重新生成 Key 后，替换下方空字符串。
 *   3. 切勿把含真实密钥的 CloudApiConfig.ets 提交到仓库。
 *
 * 安全说明：
 *   - 密钥一旦被编译进 APP 二进制，可被反编译提取，请务必在百度控制台轮换泄漏过的密钥。
 *   - 生产环境建议改用服务端代理签发 access_token，APP 侧不再持有 Secret Key。
 */

/** 百度 AI 应用的 API Key */
export const BAIDU_API_KEY: string = ''

/** 百度 AI 应用的 Secret Key */
export const BAIDU_SECRET_KEY: string = ''
