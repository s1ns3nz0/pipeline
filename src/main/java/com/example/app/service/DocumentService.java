package com.example.app.service;

import com.example.app.entity.Document;
import com.example.app.repository.DocumentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Service
public class DocumentService {

    private final DocumentRepository documentRepository;
    private final S3StorageService s3StorageService;

    public DocumentService(DocumentRepository documentRepository, S3StorageService s3StorageService) {
        this.documentRepository = documentRepository;
        this.s3StorageService = s3StorageService;
    }

    @Transactional
    public Document upload(MultipartFile file, String uploadedBy) throws IOException {
        String s3Key = "documents/" + UUID.randomUUID() + "/" + file.getOriginalFilename();

        s3StorageService.upload(s3Key, file.getInputStream(), file.getSize(), file.getContentType());

        Document document = new Document(
                file.getOriginalFilename(),
                s3Key,
                file.getContentType(),
                uploadedBy
        );
        return documentRepository.save(document);
    }

    public ResponseInputStream<GetObjectResponse> download(Long id) {
        Document document = documentRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Document not found: " + id));
        return s3StorageService.download(document.getS3Key());
    }

    public Document findById(Long id) {
        return documentRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Document not found: " + id));
    }

    public List<Document> listAll() {
        return documentRepository.findAll();
    }

    @Transactional
    public void delete(Long id) {
        Document document = documentRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Document not found: " + id));
        s3StorageService.delete(document.getS3Key());
        documentRepository.delete(document);
    }
}
