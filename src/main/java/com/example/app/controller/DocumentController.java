package com.example.app.controller;

import com.example.app.entity.Document;
import com.example.app.service.DocumentService;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.io.IOException;
import java.util.List;

@RestController
@RequestMapping("/api/documents")
public class DocumentController {

    private final DocumentService documentService;

    public DocumentController(DocumentService documentService) {
        this.documentService = documentService;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Document> upload(@RequestParam("file") MultipartFile file,
                                           @RequestParam(value = "uploadedBy", defaultValue = "anonymous") String uploadedBy)
            throws IOException {
        Document document = documentService.upload(file, uploadedBy);
        return ResponseEntity.ok(document);
    }

    @GetMapping
    public ResponseEntity<List<Document>> list() {
        return ResponseEntity.ok(documentService.listAll());
    }

    @GetMapping("/{id}")
    public ResponseEntity<Document> get(@PathVariable Long id) {
        return ResponseEntity.ok(documentService.findById(id));
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<InputStreamResource> download(@PathVariable Long id) {
        Document document = documentService.findById(id);
        ResponseInputStream<GetObjectResponse> s3Object = documentService.download(id);

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(document.getContentType()))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + document.getName() + "\"")
                .body(new InputStreamResource(s3Object));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        documentService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
