package com.example.app.repository;

import com.example.app.entity.Document;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DocumentRepository extends JpaRepository<Document, Long> {

    Optional<Document> findByS3Key(String s3Key);

    List<Document> findByUploadedBy(String uploadedBy);
}
