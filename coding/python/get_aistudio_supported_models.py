#!/bin/python3

# First method
#import google.generativeai as genai
#import os

#genai.configure(api_key=os.getenv("GOOGLE_API_KEY"))

#for model in genai.list_models():
#    if 'generateContent' in model.supported_generation_methods:
#        print(model.name)

# second method
import openai

url="https://generativelanguage.googleapis.com/v1beta/openai/",
client = openai.OpenAI(
    base_url=url,
    api_key=os.getenv("GOOGLE_API_KEY")
)

models = client.models.list()
print(f"Available models under: {base_url}") 
for model in models.data:
    print(model.id)
