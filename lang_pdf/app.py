import os
import streamlit as st
from dotenv import load_dotenv
from qa_engine import load_pdf_qa_chain
from langchain.vectorstores import FAISS
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate
from langchain.chains import RetrievalQA

load_dotenv()  #loads env stuff
st.set_page_config(page_title="PDF Q&A", layout="wide")
# st.title("📄 Ask questions about any PDF")

# uploaded_file = st.file_uploader("Choose a PDF", type=["pdf"])
st.title("📄 Ask questions across multiple PDFs")

uploaded_files = st.file_uploader("Choose one or more PDFs", type=["pdf"], accept_multiple_files=True)

if "qa_chain" not in st.session_state:
    st.session_state.qa_chain = None

if uploaded_files:
    if st.button("📥 Process PDFs"):
        uploads_dir = "uploads"
        os.makedirs(uploads_dir, exist_ok=True)

        vectorstores = []

        for uploaded_file in uploaded_files:
            pdf_path = os.path.join(uploads_dir, uploaded_file.name)

            if not os.path.exists(pdf_path):
                with open(pdf_path, "wb") as f:
                    f.write(uploaded_file.getbuffer())

            st.success(f"{uploaded_file.name} stored.")

            vs = load_pdf_qa_chain(pdf_path, return_vectorstore=True)
            vectorstores.append(vs)

        merged_vs = vectorstores[0]
        for vs in vectorstores[1:]:
            merged_vs.merge_from(vs)
        retriever = merged_vs.as_retriever(search_kwargs={"k": 8})
        llm = ChatOpenAI(model_name="gpt-4o-mini", temperature=0)

        prompt = PromptTemplate.from_template(
            """
            You are a helpful AI assistant. Given the following context from a set of documents
            and a user question, provide a detailed and insightful answer.

            Context:
            {context}

            Question:
            {question}

            Answer:
            """
        )

        qa_chain = RetrievalQA.from_chain_type(
            llm=llm,
            retriever=retriever,
            chain_type="stuff",
            chain_type_kwargs={"prompt": prompt},
            return_source_documents=True,
        )
        st.session_state.qa_chain = qa_chain
        st.success("PDFs processed. You can now ask a question 👇")

if st.session_state.qa_chain:
    user_q = st.text_input("Ask a question:")
    if user_q:
        with st.spinner("Searching and reasoning…"):
            response = st.session_state.qa_chain.invoke({"query": user_q})
            answer = response["result"]
        st.markdown("**Answer:**")
        st.write(answer)