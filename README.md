# Vapi Studio Project

**Public starter NestJS app** for [**@guidify-ai/vapi-studio**](https://www.npmjs.com/package/@guidify-ai/vapi-studio). Clone it, configure credentials for your setup, then build your conversation graph. Agents get Cursor/Claude rules and `AGENTS.md` out of the box.

| | |
| --- | --- |
| Framework | [guidify-ai/vapi-studio](https://github.com/guidify-ai/vapi-studio) · `@guidify-ai/vapi-studio@0.1.1` |
| Showcase | [vapi-studio-landing-page-sample-model](https://github.com/guidify-ai/vapi-studio-landing-page-sample-model) |
| Website | [vapi-studio.guidify.ca](https://vapi-studio.guidify.ca) — *coming soon* |
| Official team | Guidify can forward engineers onto your build — competitive rates, full professional services ([framework README](https://github.com/guidify-ai/vapi-studio#need-the-official-team)) |

## Setup checklist

Clone + `yarn start` is **not** enough by itself. Fill `.env` for the path you are taking:

### A. Machine

- [ ] Node 22+, Yarn or npm  
- [ ] Docker Compose  
- [ ] [ngrok](https://ngrok.com/download)  

### B. Always set

- [ ] `PROJECT_NAME` (and optional `PROJECT_SLUG`)  

### C. Live voice — **required**

- [ ] [Vapi](https://vapi.ai) org + **`VAPI_API_KEY`** — see [Vapi account & plans](https://github.com/guidify-ai/vapi-studio/blob/master/docs/getting-started/vapi-account.md) (**Core** recommended for a first project; free tier OK for a slow start)  
- [ ] **`POC_ASSISTANT_ID`** — assistant this app claims  
- [ ] **`VAPI_PHONE_NUMBER_ID`** — phone in Vapi with that assistant selected  
  - **Starters:** **Vapi-managed** number (no Twilio)  
  - **Larger projects:** Twilio-imported BYOK when you need your own carrier / verification path  


### D. Optional depending on setup

| Need | When | Vars |
| --- | --- | --- |
| **Twilio** | Larger / BYOK voice, and/or live **SMS** form links | `TWILIO_*` (`TWILIO_SMS_DRY_RUN=1` until ready). Paid + verification — skip for simple Vapi-phone starters |
| **Brain / LLM** | Real classification instead of MockBrain | One of `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` / `GOOGLE_API_KEY` / `XAI_API_KEY` + switch adapter in `src/app.module.ts` |
| Trust Hub / balance | Twilio BYOK +1 outbound | Twilio console (not Studio) |

Starter default brain = **MockBrain** (no LLM key). SMS dispose defaults to **dry-run**.

## Create a new bot

```bash
git clone git@github.com:guidify-ai/vapi-studio-project.git my-bot
cd my-bot
cp .env.example .env
# 1) PROJECT_NAME=…
# 2) VAPI_API_KEY + POC_ASSISTANT_ID + VAPI_PHONE_NUMBER_ID  (live voice)
# 3) TWILIO_* — skip for Vapi-phone starters; add for BYOK / live SMS
# 4) OPENAI_API_KEY (or Claude/Gemini/Grok) only if leaving MockBrain
yarn install
yarn start   # Docker Postgres + app + ngrok → prints Vapi URLs
```

`yarn start` fails closed without the Vapi claim trio. Each fork is its own deploy (own host / port / ngrok). Routes are host-scoped — no project UUID in the path.

After `yarn install`, postinstall refreshes `.cursor/rules/`, `.claude/rules/`, `AGENTS.md`, and `CLAUDE.md` from the package.

## What you get

```text
vapi-studio-project/
├── .cursor/rules/          # best-practices + UI↔API identity (AI)
├── .claude/rules/          # same doctrine for Claude Code
├── AGENTS.md / CLAUDE.md   # stamped pointers into node_modules handbook
├── config/
│   ├── project.identity.example.json
│   ├── project.identity.json          # synced from .env (gitignored)
│   └── flow.yaml
├── src/
│   ├── conversation/       # extend agent steps here
│   ├── vapi/               # webhook + Custom LLM
│   ├── brain/              # MockBrain by default
│   └── …
├── scripts/start.sh
└── docker-compose.yaml
```

## Vapi endpoints

| Setting | URL |
| --- | --- |
| Webhook | `{PUBLIC_BASE_URL}/vapi/webhook` |
| Custom LLM | `{PUBLIC_BASE_URL}/vapi/chat/completions` |

Outbound PSTN is **Vapi** dialing with your claimed phone. **Starters:** use a Vapi-managed number. **Larger projects:** import Twilio when you need BYOK.

## Local framework spoof (next package versions)

```bash
# package.json
"@guidify-ai/vapi-studio": "file:../vapi-studio"

VAPI_STUDIO_CONTEXT=../vapi-studio docker compose build
```

## Docs

- [Quick start](https://github.com/guidify-ai/vapi-studio/blob/master/docs/getting-started/quick-start.md)
- [Creating an app](https://github.com/guidify-ai/vapi-studio/blob/master/docs/building-apps/creating-an-app.md)
- [Runtime API](https://github.com/guidify-ai/vapi-studio/blob/master/docs/reference/runtime-api.md)
- [Best practices](https://github.com/guidify-ai/vapi-studio/blob/master/docs/best-practices/README.md)

## License

MIT — see [LICENSE](./LICENSE).
