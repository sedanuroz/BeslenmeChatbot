from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
import re

app = FastAPI(title="Beslenme Asistanı API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

MODEL_PATH = "./final_model"
tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH)
model = AutoModelForCausalLM.from_pretrained(MODEL_PATH)
model.eval()

class ChatRequest(BaseModel):
    question: str

class ChatResponse(BaseModel):
    answer: str

BAD_MARKERS = [
    'işaretlenmişlerdir', 'E-posta', 'GALERİ', 'Previous',
    'Next post', 'Related', 'JavaScript', 'Yorum', 'browser',
    'Okumaya devam', 'Cevabı iptal', 'yayımlanmayacak', '\t',
    'İsim *', 'Gerekli alanlar', 'ÖĞRENCİNİN',
    'Yapay zeka', 'yapay zeka', 'dil modeli', 'AI olarak',
    'kişisel tercihlerim', 'kişisel deneyimim',
]

def clean_output(raw: str) -> str:
    sentences = re.split(r'(?<=[.!?])\s+', raw)
    clean = []
    seen = set()
    for s in sentences:
        s = s.strip()
        if not s:
            continue
        if any(bad in s for bad in BAD_MARKERS):
            break
        normalized = s.lower()[:50]
        if normalized in seen:
            break
        seen.add(normalized)
        clean.append(s)
        if len(clean) >= 4:
            break
    result = ' '.join(clean).strip()
    if not result:
        result = raw.split('.')[0].strip() + '.'
    return result

@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    question = req.question.strip()

    # Soruya göre akıllı başlangıç
    if any(k in question.lower() for k in ['kilo ver', 'zayıfla', 'diyet']):
        starter = "Kilo vermek için"
    elif any(k in question.lower() for k in ['kalori', 'enerji']):
        starter = "Günlük kalori ihtiyacı"
    elif any(k in question.lower() for k in ['protein']):
        starter = "Protein kaynakları arasında"
    elif any(k in question.lower() for k in ['vitamin']):
        starter = "Vitaminler açısından"
    elif any(k in question.lower() for k in ['karbonhidrat']):
        starter = "Karbonhidratlar"
    elif any(k in question.lower() for k in ['su', 'sıvı']):
        starter = "Yeterli su tüketimi"
    elif any(k in question.lower() for k in ['kahvaltı', 'öğün']):
        starter = "Sağlıklı bir öğün"
    elif any(k in question.lower() for k in ['spor', 'egzersiz']):
        starter = "Düzenli egzersiz ve beslenme"
    else:
        starter = "Sağlıklı beslenme açısından"

    prompt = f"<|soru|>{question}\n<|cevap|>{starter}"
    inputs = tokenizer(prompt, return_tensors="pt")

    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=120,
            temperature=0.7,
            do_sample=True,
            top_p=0.9,
            repetition_penalty=1.3,
            pad_token_id=tokenizer.eos_token_id,
            eos_token_id=tokenizer.convert_tokens_to_ids("<|end|>")
        )

    generated = tokenizer.decode(outputs[0], skip_special_tokens=False)
    raw = generated.split("<|cevap|>")[-1].split("<|end|>")[0].strip()
    answer = clean_output(raw)
    return ChatResponse(answer=answer)

@app.get("/health")
async def health():
    return {"status": "ok"}