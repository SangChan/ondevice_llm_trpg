// Transformers.js를 돌리는 워커. 메인 스레드에서 생성을 돌리면 토큰이 나오는 동안
// UI가 통째로 멈춘다 — 온디바이스 추론에서 워커는 선택이 아니라 필수다.
//
// 이 워커는 게임 상태를 모른다. 프롬프트 문자열을 받아 텍스트를 돌려줄 뿐이다.

import {
  pipeline,
  InterruptableStoppingCriteria,
  TextStreamer,
  env,
} from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.1/dist/transformers.min.js";

import { countCompleteSentences } from "./sentences.js";

// 번들된 로컬 모델은 없다 — 전부 Hugging Face Hub에서 받아 브라우저 캐시에 둔다.
env.allowLocalModels = false;

let generator = null;
let loadedKey = "";

// 메시지를 직렬로 처리한다. 핸들러가 async라 그냥 두면 두 번째 load가 첫 번째가
// `generator`를 대입하기 전에 끼어들어 같은 모델을 두 번 내려받는다.
let chain = Promise.resolve();

self.addEventListener("message", (event) => {
  const message = event.data;
  chain = chain.then(async () => {
    try {
      if (message.type === "load") await load(message);
      else if (message.type === "generate") await generate(message);
    } catch (error) {
      self.postMessage({
        type: message.type === "load" ? "loadError" : "error",
        id: message.id ?? null,
        message: String(error?.message ?? error),
      });
    }
  });
});

async function load({ modelId, device, dtype }) {
  const key = `${modelId}|${device}|${dtype}`;
  if (generator && loadedKey === key) {
    self.postMessage({ type: "ready", modelId, device, cached: true });
    return;
  }

  if (generator) {
    await generator.dispose();
    generator = null;
    loadedKey = "";
  }

  generator = await pipeline("text-generation", modelId, {
    device,
    dtype,
    progress_callback: (progress) => self.postMessage({ type: "progress", progress }),
  });
  loadedKey = key;
  self.postMessage({ type: "ready", modelId, device, cached: false });
}

async function generate({ id, messages, maxNewTokens, temperature, stopAfterSentences, stream }) {
  if (!generator) throw new Error("model is not loaded");

  // 필요한 문장 수를 채우면 바로 멈춘다. 토큰 천장에 걸려 문장 중간에 끊기는 것보다
  // 낫고, 어차피 버릴 문장을 몇 초씩 더 생성하지도 않는다.
  const stopper = new InterruptableStoppingCriteria();
  let produced = "";

  const streamer = stream || stopAfterSentences > 0
    ? new TextStreamer(generator.tokenizer, {
        skip_prompt: true,
        skip_special_tokens: true,
        callback_function: (delta) => {
          produced += delta;
          // 델타가 아니라 누적 문자열을 보낸다 — 받는 쪽이 최종본과 같은 규칙으로
          // 다듬을 수 있어야 화면의 문장이 끝에서 바뀌지 않는다.
          if (stream) self.postMessage({ type: "token", id, text: produced });
          if (stopAfterSentences > 0 && countCompleteSentences(produced) >= stopAfterSentences) {
            stopper.interrupt();
          }
        },
      })
    : undefined;

  const output = await generator(messages, {
    max_new_tokens: maxNewTokens,
    temperature,
    do_sample: temperature > 0,
    top_p: 0.9,
    repetition_penalty: 1.1,
    return_dict_in_generate: false,
    stopping_criteria: stopper,
    streamer,
  });

  const turns = output[0]?.generated_text;
  const text = Array.isArray(turns) ? turns.at(-1)?.content ?? "" : String(turns ?? "");
  // 중단된 경우에도 스트리머가 본 글자는 남아 있다.
  self.postMessage({ type: "result", id, text: text || produced });
}
