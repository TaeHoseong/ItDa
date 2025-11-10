import sqlite3
import json
from tqdm import tqdm

from GPT import ask_GPT

def update_places_features():
    # Load base features
    with open("places_feature.json", "r", encoding="utf-8") as f:
        base_template = json.load(f)
        
    # Connect to db file
    conn = sqlite3.connect("./test.db")
    cur = conn.cursor()
    
    # Load places data
    cur.execute("SELECT id, place_id, name, category, rating, price_range, opening_hours, reviews, latitude, longitude, scores FROM places")
    rows = cur.fetchall()

    # Update places_features
    pbar = tqdm(rows)
    for (db_id, place_id, name, category, rating, price_range, opening_hours, reviews, latitude, longitude, scores) in pbar:
        pbar.set_postfix(name = name)
        if scores is not None:
            continue
       
        opening_hours = json.loads(opening_hours)
        reviews = json.loads(reviews)
        prompt = f"""
        아래는 장소의 기본 정보입니다:
        ---
        이름: {name}
        카테고리: {category}
        평점: {rating}
        가격대: {price_range}
        영업시간: {opening_hours}
        리뷰: {reviews}
        ---
        아래 JSON 템플릿을 참고해서, 각 항목을 0~1 사이 값으로 합리적으로 채워주세요.
        JSON 형식을 유지하고, 불필요한 설명 없이 JSON만 반환하세요.

        템플릿:
        {json.dumps(base_template, ensure_ascii=False, indent=2)}
        """
        # print(f"used prompt: {prompt}")
        result= ask_GPT(prompt)

        obj = json.loads(result)
        cur.execute("""
            UPDATE places
            SET scores = ?
            WHERE id = ?
        """, (json.dumps(obj, ensure_ascii=False), db_id))

        conn.commit()
    conn.close()
if __name__ == '__main__':
    update_places_features()