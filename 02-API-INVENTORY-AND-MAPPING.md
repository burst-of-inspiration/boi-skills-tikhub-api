# 02 API Inventory And Mapping

Status: Draft v1.0  
Last Updated: 2026-03-06

## 1. Objective
Build a complete and traceable endpoint inventory from TikHub official OpenAPI, and define the deterministic mapping from endpoint contracts to skill actions.

## 2. Source Snapshot
- Source: `https://api.tikhub.io/openapi.json`
- Snapshot date: 2026-03-06
- OpenAPI version: `3.1.0`
- API info version: `V5.3.2`
- Total operations: `987`
- HTTP methods: `GET=874`, `POST=113`
- Platforms detected: `26`

Snapshot regeneration command:
```bash
curl -fsSL https://api.tikhub.io/openapi.json -o /tmp/tikhub-openapi.json
boi-skills-tikhub-api/scripts/generate_inventory.sh /tmp/tikhub-openapi.json boi-skills-tikhub-api
```

## 3. Machine-Readable Deliverables
This document is backed by generated CSV files:
- `02-API-INVENTORY.csv` (full operation-level rows)
- `02-API-SUMMARY-PLATFORM.csv` (platform totals)
- `02-API-SUMMARY-MODULE.csv` (platform+module totals)

These files are the source of truth for implementation progress tracking.

## 4. Inventory Summary By Platform

| Platform | Operations |
|---|---:|
| douyin | 247 |
| tiktok | 204 |
| instagram | 82 |
| xiaohongshu | 68 |
| weibo | 64 |
| bilibili | 41 |
| youtube | 37 |
| kuaishou | 33 |
| zhihu | 32 |
| linkedin | 25 |
| reddit | 24 |
| pipixia | 17 |
| sora2 | 17 |
| lemon8 | 16 |
| twitter | 13 |
| threads | 11 |
| wechat_mp | 10 |
| demo | 9 |
| wechat_channels | 9 |
| tikhub | 8 |
| toutiao | 7 |
| xigua | 7 |
| temp_mail | 3 |
| health | 1 |
| hybrid | 1 |
| ios_shortcut | 1 |

## 5. Inventory Summary By Module

| Platform | Module | Operations |
|---|---|---:|
| bilibili | web | 30 |
| bilibili | app | 11 |
| demo | douyin | 2 |
| demo | tiktok | 2 |
| demo | demo | 1 |
| demo | douyin_search | 1 |
| demo | instagram | 1 |
| demo | kuaishou | 1 |
| demo | wechat | 1 |
| douyin | web | 76 |
| douyin | app | 47 |
| douyin | billboard | 31 |
| douyin | xingtu | 22 |
| douyin | xingtu_v2 | 21 |
| douyin | search | 20 |
| douyin | creator | 16 |
| douyin | creator_v2 | 14 |
| health | root | 1 |
| hybrid | root | 1 |
| instagram | v1 | 29 |
| instagram | v2 | 27 |
| instagram | v3 | 26 |
| ios_shortcut | root | 1 |
| kuaishou | app | 20 |
| kuaishou | web | 13 |
| lemon8 | app | 16 |
| linkedin | web | 25 |
| pipixia | app | 17 |
| reddit | app | 24 |
| sora2 | root | 17 |
| temp_mail | v1 | 3 |
| threads | web | 11 |
| tikhub | user | 6 |
| tikhub | downloader | 2 |
| tiktok | app | 75 |
| tiktok | web | 58 |
| tiktok | ads | 31 |
| tiktok | shop | 15 |
| tiktok | creator | 14 |
| tiktok | interaction | 7 |
| tiktok | analytics | 4 |
| toutiao | app | 5 |
| toutiao | web | 2 |
| twitter | web | 13 |
| wechat_channels | root | 9 |
| wechat_mp | web | 10 |
| weibo | web_v2 | 33 |
| weibo | app | 20 |
| weibo | web | 11 |
| xiaohongshu | app_v2 | 21 |
| xiaohongshu | web_v2 | 18 |
| xiaohongshu | web | 17 |
| xiaohongshu | app | 12 |
| xigua | app | 7 |
| youtube | web | 21 |
| youtube | web_v2 | 16 |
| zhihu | web | 32 |

## 6. Endpoint To Skill Action Mapping Rules

### 6.1 Canonical Action Name
Action naming is deterministic from path:
- Path pattern A: `/api/v1/{platform}/{module}/{endpoint...}`
  - action: `{platform}.{module}.{endpoint_joined_with_underscore}`
- Path pattern B: `/api/v1/{platform}/{endpoint}`
  - module: `root`
  - action: `{platform}.root.{endpoint}`

Examples:
- `/api/v1/tiktok/web/fetch_user_profile` -> `tiktok.web.fetch_user_profile`
- `/api/v1/wechat_channels/fetch_comments` -> `wechat_channels.root.fetch_comments`
- `/api/v1/sora2/get_task_status` -> `sora2.root.get_task_status`

### 6.2 Required Mapping Fields
Every operation mapping row must include:
- `method`
- `path`
- `operation_id`
- `platform`
- `module`
- `endpoint`
- `action_name`

### 6.3 Collision And Uniqueness Policy
- `operation_id` is unique in this snapshot and used as immutable reference key.
- `action_name` must be unique per release.
- If future OpenAPI changes create conflicts, suffix with explicit version token at action layer (final policy in Doc 05).

## 7. Packaging Strategy For Full Coverage

### 7.1 Target Packaging Layout
- One repository, multi-skill packages grouped by platform domain.
- Each platform skill owns its own action set and tests.
- Optional aggregate discovery skill lists available platform skills.

### 7.2 Suggested Initial Skill Partition
- `skill-tikhub-core`: `health`, `tikhub`, `temp_mail`, `hybrid`, `ios_shortcut`
- `skill-tikhub-douyin-family`: `douyin`, `xigua`, `toutiao`, `weibo`, `xiaohongshu`
- `skill-tikhub-global-social`: `tiktok`, `instagram`, `twitter`, `threads`, `reddit`, `linkedin`, `youtube`
- `skill-tikhub-video-community`: `bilibili`, `kuaishou`, `pipixia`, `lemon8`, `wechat_mp`, `wechat_channels`, `zhihu`
- `skill-tikhub-experimental`: `sora2`, `demo`

Final partition decision will be locked in Doc 04.

## 8. Implementation Slicing Plan (By Operation Volume)

| Batch | Primary Platforms | Estimated Ops | Goal |
|---|---|---:|---|
| B1 | douyin + tiktok | 451 | Validate core architecture and naming stability |
| B2 | instagram + xiaohongshu + weibo | 214 | Handle multi-version module patterns |
| B3 | bilibili + youtube + kuaishou + zhihu | 143 | Consolidate web/app mixed adapters |
| B4 | linkedin + reddit + pipixia + sora2 + lemon8 | 99 | Complete medium-size domains |
| B5 | remaining long-tail platforms | 80 | Close full coverage gap |

## 9. Progress Tracking Model
Implementation board should be keyed by `operation_id` and include:
- `status` (`todo` | `in_progress` | `done` | `blocked`)
- `owner`
- `skill_package`
- `test_case_id`
- `last_verified_at`
- `notes`

## 10. Acceptance Criteria
This document phase is accepted when:
- Full operation inventory is generated and committed.
- Platform/module counts are reproducible from script.
- Deterministic action mapping rule is approved.
- Implementation slicing baseline is approved.
- Ready to execute `03-AUTH-RATE-LIMIT-AND-RETRY.md` and `04-SKILL-ARCHITECTURE.md`.

## 11. Risks And Constraints

| Risk | Impact | Mitigation |
|---|---|---|
| OpenAPI updates after snapshot | Count and mapping drift | Regenerate CSV via script and keep snapshot date in changelog |
| Deep path heterogeneity | Naming inconsistency | Enforce deterministic path-to-action algorithm |
| Large operation count | Delivery delay | Batch-by-volume execution with explicit phase gates |
| Unknown endpoint behavior | Runtime failures | Defer runtime specifics to Doc 03 and error model in Doc 06 |

## 12. Exit Checklist
- [ ] `02-API-INVENTORY.csv` reviewed
- [ ] `02-API-SUMMARY-PLATFORM.csv` reviewed
- [ ] `02-API-SUMMARY-MODULE.csv` reviewed
- [ ] Mapping rule approved
- [ ] Batch plan approved
