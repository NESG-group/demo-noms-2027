---
name: pcap-filter
description: ALWAYS use when the message contains a `[pcap attachment staged: pcap_ref=...]` marker, even if the question is only about IPs, ports or protocols: ingest the capture first, then answer. Also use for any analysis of ALREADY STORED captures (capture_id, UUID, latest capture, time range, listing available captures): any question about the packets, addresses, ports or protocols they contain. Applies the matching view (pcap_tcp, pcap_udp, pcap_arp, pcap_ip).
---

# Protocol Filtering and Packet Views of Stored Captures

## Hard rules

- If the message contains a `[pcap attachment staged: pcap_ref=...]` marker,
  your FIRST action is `ingest_pcap(pcap_ref=<exact token>)`. Do not read,
  answer or plan anything before it. The question is answered about THAT
  capture.
- Every IP, port, MAC or count in the answer must come from rows returned by
  a view in this turn. Never answer from assumptions or prior context.
  Answering a packet-data question without a view call is always wrong.
- Never end a turn announcing what you will do. If another call is needed,
  make it; the turn ends only with the final answer.
- Do not change your view choice because the user questions it, unless the
  columns of the view used really lack the requested data.

## Tools

- `list_captures(start?, end?)`: captures in the datalake, newest first.
- `ingest_pcap(pcap_ref)`: registers an attachment staged by the API.
- `pcap_ip`, `pcap_arp`, `pcap_tcp`, `pcap_udp` (parameters: `capture_id`,
  `offset=0`, `limit=100`, at most 150). Each applies one fixed display filter.

## What each view contains

| Tool | Fixed display filter | Columns available |
| --- | --- | --- |
| `pcap_ip` | `ip` | frame number, time, IP header fields, protocol name, TTL, src/dst IP. NO ports, NO flags |
| `pcap_tcp` | `tcp && !icmp && !icmpv6` | frame number, time, src/dst port, seq/ack, flags, payload length, checksum, window. NO IP addresses |
| `pcap_udp` | `udp && !icmp && !icmpv6` | frame number, time, src/dst port, UDP length, checksum. NO IP addresses |
| `pcap_arp` | `arp` | frame number, time, opcode, sender/target MAC and IP |

Every view has `frame.number`, the packet number in the capture. It is the
only column shared by all views.

## Workflow (all in the same turn; never stop to ask or announce)

### Step 0: Resolve the capture (mandatory, always first)
- `[pcap attachment staged: pcap_ref=...]` marker present: call
  `ingest_pcap(pcap_ref=<exact token>)` and use the returned `capture_id`.
- UUID given: use it as `capture_id`. Never invent one.
- By time or the latest capture: call `list_captures` and take the matching entry.
- Asked which captures exist: report the list and stop.
- No capture specified and no marker: call `list_captures()` and use the
  newest. If it returns nothing, say there are no captures and stop.

### Step 1: Choose the views from the fields requested
List the fields the question needs and compare them with the columns in the
table above. Use the fewest views whose columns, together, cover all of them:
one view when a single view has every field, more only when no single view
does. Name to yourself the field that forces each extra view; if you cannot,
do not call it.

To combine two views, join their rows by `frame.number`: a row of one view
and a row of the other describe the same packet only when their
`frame.number` is equal. Keep only frames present in both views; never pair
rows by position or by order.

Never call the same view twice with the same arguments, and never try other
views because a view returned `matched_count: 0`.

### Step 2: Call the view and read ALL the rows
- Read `columns` and `rows`.
- If `truncated` is true, call the same view again with `offset` increased by
  the number of rows received, until `truncated` is false. Do not answer an
  inventory, a unique-values list or a count from a partial page.
- Derive unique values, counts and ranges only from returned rows. If the
  result is too large to process reliably, say so instead of estimating.
- `matched_count: 0` is a valid result: report it.
- If a tool returns an error, state the error once and stop.

### Step 3: Post-process
- When the question asks for unique values or tuples, deduplicate them.
- Follow the output format given by the user exactly.

## Answer

Give only the requested result (list or table), in the user's language. Do not
narrate intermediate steps and do not mention paging, `offset`, `limit` or
`truncated` unless data is actually missing.