package com.example.app;

import com.example.app.entity.Document;
import com.example.app.repository.DocumentRepository;
import com.example.app.service.DocumentService;
import com.example.app.service.S3StorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DocumentServiceTest {

    @Mock
    private DocumentRepository documentRepository;

    @Mock
    private S3StorageService s3StorageService;

    @Mock
    private MultipartFile multipartFile;

    private DocumentService documentService;

    @BeforeEach
    void setUp() {
        documentService = new DocumentService(documentRepository, s3StorageService);
    }

    @Test
    void upload_savesMetadataAndUploadsToS3() throws IOException {
        when(multipartFile.getOriginalFilename()).thenReturn("test.pdf");
        when(multipartFile.getContentType()).thenReturn("application/pdf");
        when(multipartFile.getSize()).thenReturn(1024L);
        when(multipartFile.getInputStream()).thenReturn(new ByteArrayInputStream(new byte[1024]));
        when(documentRepository.save(any(Document.class))).thenAnswer(inv -> inv.getArgument(0));

        Document result = documentService.upload(multipartFile, "testuser");

        assertEquals("test.pdf", result.getName());
        assertEquals("application/pdf", result.getContentType());
        assertEquals("testuser", result.getUploadedBy());
        assertTrue(result.getS3Key().startsWith("documents/"));
        assertTrue(result.getS3Key().endsWith("/test.pdf"));

        verify(s3StorageService).upload(eq(result.getS3Key()), any(), eq(1024L), eq("application/pdf"));
        verify(documentRepository).save(any(Document.class));
    }

    @Test
    void delete_removesFromS3AndDatabase() {
        Document doc = new Document("test.pdf", "documents/abc/test.pdf", "application/pdf", "user");
        when(documentRepository.findById(1L)).thenReturn(Optional.of(doc));

        documentService.delete(1L);

        verify(s3StorageService).delete("documents/abc/test.pdf");
        verify(documentRepository).delete(doc);
    }

    @Test
    void findById_throwsWhenNotFound() {
        when(documentRepository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(IllegalArgumentException.class, () -> documentService.findById(99L));
    }

    @Test
    void listAll_returnsList() {
        Document doc = new Document("a.txt", "documents/1/a.txt", "text/plain", "user");
        when(documentRepository.findAll()).thenReturn(List.of(doc));

        List<Document> result = documentService.listAll();

        assertEquals(1, result.size());
        assertEquals("a.txt", result.get(0).getName());
    }
}
