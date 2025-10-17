import sqlite3
import json

from GPT import ask_GPT

def update_places_features():
    # Load base features
    with open("places_feature.json", "r", encoding="utf-8") as f:
        base_template = json.load(f)
        
    # Connect to db file
    conn = sqlite3.connect("backend/test.db")
    cur = conn.cursor()
    
    # Load places data
    cur.execute("SELECT name, category, rating, price_range, opening_hours FROM places")
    rows = cur.fetchall()

    # Update places_features
    for (name, category, rating, price_range, opening_hours) in rows:
        opening_hours = json.loads(opening_hours)
        prompt = f"""
        아래는 장소의 기본 정보입니다:
        ---
        이름: {name}
        카테고리: {category}
        평점: {rating}
        가격대: {price_range}
        영업시간: {opening_hours}
        ---
        아래 JSON 템플릿을 참고해서, 각 항목을 0~1 사이 값으로 합리적으로 채워주세요.
        JSON 형식을 유지하고, 불필요한 설명 없이 JSON만 반환하세요.

        템플릿:
        {json.dumps(base_template, ensure_ascii=False, indent=2)}
        """
        print(f"used prompt: {prompt}")
        result= ask_GPT(prompt)
        print(result)
        break

if __name__ == '__main__':
    update_places_features()