// 문장 단위 다루기. 워커(생성 중단 판단)와 narrator(화면 표시·최종 다듬기)가 같은 규칙을
// 써야 화면에 흘러가던 문장이 끝에서 사라지지 않는다.

/// 종결 부호로 끝나는 문장 하나. 닫는 따옴표·괄호까지 문장에 포함한다.
const SENTENCE = /[^.!?]+[.!?]+(?:["')\]]+)?/g;

export function completeSentences(text) {
  return String(text ?? "").match(SENTENCE) ?? [];
}

export function countCompleteSentences(text) {
  return completeSentences(text).length;
}

/// 완결된 문장들을 뺀 나머지 — 아직 쓰는 중인 마지막 문장.
export function unfinishedTail(text) {
  const consumed = completeSentences(text).join("").length;
  return String(text ?? "").slice(consumed).trim();
}
