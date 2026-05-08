from datasets import load_dataset, Dataset
from transformers import (
    AutoTokenizer, AutoModelForCausalLM,
    TrainingArguments, Trainer,
    DataCollatorForLanguageModeling
)
import json, random

MODEL_NAME = "ytu-ce-cosmos/turkish-gpt2"

keywords = ['beslen', 'kalori', 'diyet', 'protein', 'vitamin',
            'sağlık', 'yemek', 'gıda', 'besin', 'kilo', 'yağ',
            'karbonhidrat', 'mineral', 'spor', 'egzersiz', 'öğün',
            'meyve', 'sebze', 'tahıl', 'süt', 'et', 'balık']

def is_nutrition(example):
    # InstrucTurca kolonları: "Input" ve "Output"
    text = (example.get('Input', '') + example.get('Output', '')).lower()
    return any(kw in text for kw in keywords)

def tokenize_fn(examples):
    return tokenizer(
        examples["text"],
        truncation=True,
        max_length=256,
        padding="max_length"
    )

if __name__ == '__main__':
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)

    tokenizer.add_special_tokens({
        "additional_special_tokens": ["<|soru|>", "<|cevap|>", "<|end|>"]
    })
    tokenizer.pad_token = tokenizer.eos_token
    model.resize_token_embeddings(len(tokenizer))

    # 1. Kendi temizlenmiş verimizi yükle
    print("Kendi veri seti yükleniyor...")
    with open("data/train.jsonl", encoding="utf-8") as f:
      own_train = [json.loads(l) for l in f]
    with open("data/val.jsonl", encoding="utf-8") as f:
      own_val = [json.loads(l) for l in f]
    print(f"Kendi veri: {len(own_train)} train, {len(own_val)} val")

    # 2. InstrucTurca'dan beslenme filtrele
    print("InstrucTurca yükleniyor (100k örnek)...")
    hf_dataset = load_dataset(
        "turkish-nlp-suite/InstrucTurca",
        split="train[:100000]"
    )
    print("Filtreleniyor...")
    filtered = hf_dataset.filter(is_nutrition)
    print(f"HF'den filtrelenmiş: {len(filtered)} kayıt")

    # 3. HF verisini kendi formatımıza çevir
    hf_texts = []
    for item in filtered:
        instruction = item.get("Input", "").strip()
        output = item.get("Output", "").strip()
        if instruction and output and len(output) > 30:
            text = f"<|soru|>{instruction}\n<|cevap|>{output}<|end|>"
            hf_texts.append({"text": text})

    print(f"Kullanılabilir HF kayıt: {len(hf_texts)}")

    # 4. Birleştir
    all_train = own_train + hf_texts
    random.seed(42)
    random.shuffle(all_train)
    print(f"Toplam train: {len(all_train)}, val: {len(own_val)}")

    # 5. Dataset objelerine çevir
    train_dataset = Dataset.from_list(all_train)
    val_dataset = Dataset.from_list(own_val)

    train_tokenized = train_dataset.map(tokenize_fn, batched=True, remove_columns=["text"])
    val_tokenized = val_dataset.map(tokenize_fn, batched=True, remove_columns=["text"])

    training_args = TrainingArguments(
        output_dir="./model_output",
        num_train_epochs=3,
        per_device_train_batch_size=2,
        gradient_accumulation_steps=8,
        learning_rate=5e-5,
        weight_decay=0.01,
        warmup_steps=100,
        logging_steps=50,
        save_strategy="epoch",
        eval_strategy="epoch",
        load_best_model_at_end=True,
        fp16=True,
        report_to="none"
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_tokenized,
        eval_dataset=val_tokenized,
        data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False)
    )

    trainer.train()
    trainer.save_model("./final_model")
    tokenizer.save_pretrained("./final_model")
    print("✓ Eğitim tamamlandı!")