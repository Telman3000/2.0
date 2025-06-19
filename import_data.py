import os
import glob
import json
import csv
from pymongo import MongoClient

# -------------------------------------------------------------------
# Настройки подключения к MongoDB
# -------------------------------------------------------------------
MONGO_URI = os.getenv('MONGO_URI', 'mongodb://localhost:27017/')
DB_NAME   = 'namaz_db'

client = MongoClient(MONGO_URI)
db     = client[DB_NAME]

# -------------------------------------------------------------------
# 1) Загрузка пользователей (learners)
# -------------------------------------------------------------------
learners_path = 'namaz_learners_anon.json'
with open(learners_path, encoding='utf-8') as f:
    learners = json.load(f)

col_learners = db['users_learners']
col_learners.delete_many({})          # очистка коллекции
col_learners.insert_many(learners)    # вставка всех документов
print(f"✔ Loaded {len(learners)} documents into 'users_learners'")

# -------------------------------------------------------------------
# 2) Загрузка логов (logs)
# -------------------------------------------------------------------
# ищем любой файл namaz_logs_anon*.json
log_candidates = glob.glob('namaz_logs_anon*.json')
if not log_candidates:
    raise FileNotFoundError("Не найден файл namaz_logs_anon*.json")
logs_path = log_candidates[0]

with open(logs_path, encoding='utf-8-sig') as f:
    logs = json.load(f)

col_logs = db['users_logs']
col_logs.delete_many({})
col_logs.insert_many(logs)
print(f"✔ Loaded {len(logs)} documents into 'users_logs' (from '{logs_path}')")

# -------------------------------------------------------------------
# 3) Загрузка результатов оценок (outcomes)
# -------------------------------------------------------------------
outcomes_path = 'namaz_outcomes.csv'
col_outcomes  = db['outcomes']
col_outcomes.delete_many({})

with open(outcomes_path, encoding='utf-8') as f:
    reader   = csv.DictReader(f)
    outcomes = [row for row in reader]

col_outcomes.insert_many(outcomes)
print(f"✔ Loaded {len(outcomes)} records into 'outcomes'")

# -------------------------------------------------------------------
# 4) Загрузка структуры приложения (app_structure)
# -------------------------------------------------------------------
structure_path = 'app_structure.json'
with open(structure_path, encoding='utf-8') as f:
    structure = json.load(f)

col_app_struct = db['app_structure']
col_app_struct.delete_many({})

# Если структура — список документов, вставляем их все
if isinstance(structure, list):
    col_app_struct.insert_many(structure)
    print(f"✔ Loaded {len(structure)} documents into 'app_structure'")
# Если структура — один объект (словарь), вставляем единичный документ
elif isinstance(structure, dict):
    col_app_struct.insert_one(structure)
    print("✔ Loaded 1 document into 'app_structure'")
else:
    raise TypeError("app_structure.json должен быть либо списком, либо словарём")

print("\n✅ All data successfully imported into MongoDB.")