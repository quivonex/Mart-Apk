from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.test import SimpleTestCase

from company.shiprocket import create_company_pickup_location


class CompanyShiprocketPickupLocationTests(SimpleTestCase):
    @patch("company.shiprocket.get_shiprocket_token", return_value="token")
    @patch("company.shiprocket.requests.post")
    @patch("company.shiprocket.requests.get")
    def test_created_shiprocket_nickname_is_saved_on_company(
        self, mock_get, mock_post, _mock_token
    ):
        company = SimpleNamespace(
            id=42,
            name="QNX Mart",
            address="Sr. No. 402, Shree Datta Laxmi Banglow",
            village="Kodoli",
            taluka="Satara",
            district="Satara",
            state="Maharashtra",
            pincode="415004",
            email="seller@example.com",
            phone_number="9876543210",
            owner_name="Seller",
            pickup_location="Sr. No. 402, Shree Datta Laxmi Banglow",
            save=Mock(),
        )
        mock_get.return_value = Mock(status_code=200)
        mock_get.return_value.json.return_value = {"data": {"shipping_address": []}}
        mock_post.return_value = Mock(status_code=201)
        mock_post.return_value.json.return_value = {"success": True}

        result = create_company_pickup_location(company)

        self.assertEqual(result["pickup_location"], "QNXMart42")
        self.assertEqual(company.pickup_location, "QNXMart42")
        company.save.assert_called_once_with(update_fields=["pickup_location"])
