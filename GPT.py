from openai import OpenAI
OPENAI_API_KEY ="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"

def ask_GPT(prompt):
    client = OpenAI(api_key=OPENAI_API_KEY)
    response = client.responses.create(
        model="gpt-5",
        input=prompt
    )
    return response.output_text

if __name__ == '__main__':
    prompt = input("Ask something to GPT: ")
    result = ask_GPT(prompt)
    print(result)
    