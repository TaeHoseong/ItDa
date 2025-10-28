import os
import sys
import urllib.request
from app.config import settings

client_id = NAVER_CLIENT_ID
client_secret = NAVER_CLIENT_SECRET

def search_place(place: str, num_places: int, start: int):
    input = f"{place} 맛집"
    encText = urllib.parse.quote(input)
    display = str(num_places)  # 원하는 결과 개수
    url = "https://openapi.naver.com/v1/search/local?query=" + encText \
        + "&display=" + str(display) + "&start=" + str(start)

    request = urllib.request.Request(url)
    request.add_header("X-Naver-Client-Id", client_id)
    request.add_header("X-Naver-Client-Secret", client_secret)
    response = urllib.request.urlopen(request)
    rescode = response.getcode()
    if(rescode==200):
        response_body = response.read()
        result = response_body.decode('utf-8')
    else:
        print("Error Code:" + str(rescode))
        return None
    return result

if __name__ == "__main__":
    result = search_place("인천 송도", 5, 2)
    print(result)