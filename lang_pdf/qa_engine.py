"""
Lightweight PDF → VectorStore → Retrieval-QA pipeline
"""
import os
import io
from PIL import Image
import fitz  # PyMuPDF
import torch
import clip
import numpy as np
from sklearn.decomposition import PCA
from pathlib import Path
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.chains import RetrievalQA
from langchain_community.document_loaders import UnstructuredPDFLoader
from langchain_core.documents import Document
from langchain_community.vectorstores import FAISS
from langchain_openai import OpenAIEmbeddings


EMBEDDING_MODEL = "text-embedding-3-small"
CHUNK_SIZE = 1000      # characters
CHUNK_OVERLAP = 200    # characters
PERSIST_BASE = ".indices"   # root folder for FAISS indices
CLIP_DIM = 512
TEXT_DIM = 1536

device = "cuda" if torch.cuda.is_available() else "cpu"
clip_model, clip_preprocess = clip.load("ViT-B/32", device=device)

R = np.random.normal(size=(CLIP_DIM, TEXT_DIM)).astype(np.float32) / np.sqrt(TEXT_DIM)


def _index_path(pdf_path: str) -> str:
    """Return a unique on-disk folder for this PDF’s FAISS index."""
    name = Path(pdf_path).stem.replace(" ", "_")
    return os.path.join(PERSIST_BASE, name)

def _extract_images(pdf_path: str) -> list[Document]:
    pdf_doc = fitz.open(pdf_path)
    image_docs = []

    for p in range(len(pdf_doc)):
        page = pdf_doc[p]
        images = page.get_images(full=True)
        #print(len(images))
        for i, img in enumerate(images):
            xref = img[0]
            base_image = pdf_doc.extract_image(xref)
            image_bytes = base_image["image"]
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")

            tensor = clip_preprocess(image).unsqueeze(0).to(device)
            with torch.no_grad():
                vector = clip_model.encode_image(tensor).cpu().numpy().astype(np.float32)[0]
                vector_384 = vector @ R

            img_doc = Document(page_content="[IMAGE]", metadata={"type": "image", "page": p + 1, "image_index": i})
            img_doc._embedding = vector_384
            image_docs.append(img_doc)

    pdf_doc.close()
    return image_docs


def _build_vectorstore(pdf_path: str, persist_dir: str) -> FAISS:
    """Load PDF, chunk, embed, store in FAISS (and persist)."""
    loader = UnstructuredPDFLoader(pdf_path, mode="elements")
    pages = loader.load()                            # one doc / page
    splitter = RecursiveCharacterTextSplitter(chunk_size=CHUNK_SIZE, chunk_overlap=CHUNK_OVERLAP)
    text_docs = splitter.split_documents(pages)

    text_embeddings = OpenAIEmbeddings(model=EMBEDDING_MODEL)
    text_vectorstore = FAISS.from_documents(text_docs, text_embeddings)

    image_docs = _extract_images(pdf_path)
    if image_docs:
        items = [(d.page_content, d._embedding.tolist()) for d in image_docs]
        metas = [d.metadata for d in image_docs]
        text_vectorstore.add_embeddings(items, metadatas=metas)

    text_vectorstore.save_local(persist_dir)
    return text_vectorstore


def load_pdf_qa_chain(pdf_path: str, return_vectorstore: bool) -> RetrievalQA:
    os.makedirs(PERSIST_BASE, exist_ok=True)
    persist_dir = _index_path(pdf_path)

    if os.path.exists(os.path.join(persist_dir, "index.faiss")):
        vectorstore = FAISS.load_local(persist_dir, OpenAIEmbeddings(model=EMBEDDING_MODEL), allow_dangerous_deserialization=True)
    else:
        vectorstore = _build_vectorstore(pdf_path, persist_dir)

    return vectorstore


