from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/')
def home():
    return "Bienvenue sur l'API du Blog SaaS !"

@app.route('/api/posts')
def get_posts():
    return jsonify([
        {"id": 1, "title": "Mon premier post", "content": "Le DevOps c'est super !"},
        {"id": 2, "title": "Terraform", "content": "L'infra as code avec LocalStack."}
    ])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
