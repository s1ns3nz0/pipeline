package com.example.app.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "documents")
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(name = "s3_key", nullable = false, unique = true)
    private String s3Key;

    @Column(name = "content_type")
    private String contentType;

    @Column(name = "uploaded_by")
    private String uploadedBy;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    protected Document() {
    }

    public Document(String name, String s3Key, String contentType, String uploadedBy) {
        this.name = name;
        this.s3Key = s3Key;
        this.contentType = contentType;
        this.uploadedBy = uploadedBy;
        this.createdAt = Instant.now();
    }

    public Long getId() { return id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getS3Key() { return s3Key; }

    public String getContentType() { return contentType; }

    public String getUploadedBy() { return uploadedBy; }

    public Instant getCreatedAt() { return createdAt; }
}
