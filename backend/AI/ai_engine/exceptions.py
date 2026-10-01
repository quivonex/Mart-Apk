class AIEngineError(Exception):
    """
    Base exception for the AI engine.
    """
    pass


class ProviderError(AIEngineError):
    """
    AI provider related error.
    """
    pass


class DocumentProcessingError(AIEngineError):
    """
    PDF/document processing error.
    """
    pass


class ImageExtractionError(AIEngineError):
    """
    PDF image extraction error.
    """
    pass


class StorageError(AIEngineError):
    """
    Storage/S3 related error.
    """
    pass


class ExtractionError(AIEngineError):
    """
    Overall extraction process error.
    """
    pass