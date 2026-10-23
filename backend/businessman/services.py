import pandas as pd
from django.db import transaction

from .models import Businessman


class CSVImportService:
    """CSV → Database import service"""

    @classmethod
    def import_from_file(cls, file_obj, batch_size=500, chunk_size=5000):

        success_count = 0
        error_count = 0
        errors = []
        total_rows = 0

        try:
            # Read CSV in chunks so large files don't consume too much memory
            chunks = pd.read_csv(
                file_obj,
                dtype=str,
                keep_default_na=False,
                chunksize=chunk_size
            )

            first_chunk = True

            for df in chunks:

                # ==========================================
                # CLEAN COLUMN NAMES
                # ==========================================
                df.columns = [str(c).strip() for c in df.columns]

                # ==========================================
                # CHECK REQUIRED COLUMN
                # ==========================================
                if first_chunk:

                    if 'company_name' not in df.columns:
                        return {
                            'success': False,
                            'message': "Missing 'company_name' column",
                            'total_rows': 0,
                            'success_count': 0,
                            'error_count': 0,
                            'errors': []
                        }

                    first_chunk = False

                # ==========================================
                # REMOVE EMPTY COMPANY NAME
                # ==========================================
                df = df[
                    df['company_name']
                    .astype(str)
                    .str.strip() != ''
                ]

                total_rows += len(df)

                records = []

                # ==========================================
                # CONVERT ROWS
                # ==========================================
                for idx, row in df.iterrows():

                    try:
                        record = cls._row_to_model(row)

                        records.append(record)

                    except Exception as e:

                        error_count += 1

                        errors.append({
                            'row': idx + 2,
                            'error': str(e)
                        })

                        if len(errors) >= 50:
                            continue

                # ==========================================
                # BULK INSERT
                # ==========================================
                if records:

                    try:

                        with transaction.atomic():

                            created_records = Businessman.objects.bulk_create(
                                records,
                                batch_size=batch_size,
                                ignore_conflicts=True
                            )

                        # Actual records inserted
                        success_count += len(created_records)

                        # If conflicts happened
                        conflict_count = len(records) - len(created_records)

                        if conflict_count > 0:
                            error_count += conflict_count

                    except Exception as e:

                        error_count += len(records)

                        if len(errors) < 50:
                            errors.append({
                                'row': 'batch',
                                'error': str(e)
                            })

            return {
                'success': True,
                'message': 'CSV import completed successfully.',
                'total_rows': total_rows,
                'success_count': success_count,
                'error_count': error_count,
                'errors': errors[:50]
            }

        except Exception as e:

            return {
                'success': False,
                'message': f'CSV read/import error: {str(e)}',
                'total_rows': total_rows,
                'success_count': success_count,
                'error_count': error_count,
                'errors': errors[:50]
            }

    @classmethod
    def _row_to_model(cls, row):

        def get(field):

            val = row.get(field, '')

            if pd.isna(val):
                return None

            val = str(val).strip()

            return val if val else None

        # ==========================================
        # EMAIL SCORE
        # ==========================================

        score = get('email_score')

        try:

            email_score = int(float(score)) if score else None

        except (ValueError, TypeError):

            email_score = None

        # ==========================================
        # BUSINESSMAN OBJECT
        # ==========================================

        return Businessman(
            company_name=get('company_name') or 'Unknown',

            ai_business_category=get(
                'ai_business_category'
            ),

            contact_person=get(
                'contact_person'
            ),

            gender=get(
                'gender'
            ),

            mobile=get(
                'mobile'
            ),

            phone_validation_status=get(
                'phone_validation_status'
            ),

            email=get(
                'email'
            ),

            email_type=get(
                'email_type'
            ),

            email_score=email_score,

            original_catalog_url=get(
                'original_catalog_url'
            ),

            catalog_link_status=get(
                'catalog_link_status'
            ),

            city=get(
                'city'
            ),

            state=get(
                'state'
            ),

            pincode=get(
                'pincode'
            ),

            full_address=get(
                'full_address'
            ),

            seller_type=get(
                'seller_type'
            ),
        )