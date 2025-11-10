from openai import OpenAI
OPENAI_API_KEY ="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"
client = OpenAI(api_key=OPENAI_API_KEY)
def ask_GPT(prompt):
    response = client.chat.completions.create(
        model="gpt-5",
        messages=[
            {"role": "user", "content": prompt}
        ]
    )
    return response.choices[0].message.content

if __name__ == '__main__':
    prompt = input("Ask something to GPT: ")
    result = ask_GPT(prompt)
    print(result)
    