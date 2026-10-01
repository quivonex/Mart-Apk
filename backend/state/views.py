from django.shortcuts import render

# Create your views here.
from django.shortcuts import render # type: ignore

# Create your views here.
from rest_framework.views import APIView # type: ignore
from rest_framework.response import Response # type: ignore
from rest_framework import status # type: ignore
from .models import State,District,Taluka
from .serializers import StateSerializer,DistrictSerializer,TalukaSerializer
from django.shortcuts import get_object_or_404 # type: ignore

# CREATE
class StateCreateAPIView(APIView):
    def post(self, request):

        data = request.data

        # जर list आली तर many=True
        many = isinstance(data, list)

        serializer = StateSerializer(data=data, many=many)

        if serializer.is_valid():
            serializer.save()
            return Response(
                {
                    "msg": "State created successfully",
                    "status": "success",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "msg": "Validation failed",
                "status": "error",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )

# UPDATE
class StateUpdateAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('id')
        state_instance = get_object_or_404(State, id=state_id)
        
        serializer = StateSerializer(state_instance, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'msg': 'State updated successfully',
                'status': 'success',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        return Response({
            'msg': 'Validation failed',
            'status': 'error',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


# RETRIEVE SINGLE
class StateRetrieveAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('id')
        state_instance = get_object_or_404(State, id=state_id)
        serializer = StateSerializer(state_instance)
        return Response({
            'msg': 'State fetched successfully',
            'status': 'success',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


# RETRIEVE ALL
class StateListActiveAPIView(APIView):
    def post(self, request):
        states = State.objects.filter(is_active=True,flag=True).order_by('state_name')
        serializer = StateSerializer(states, many=True)
        return Response({
            'msg': 'All states fetched successfully',
            'status': 'success',
            'data': serializer.data
        }, status=status.HTTP_200_OK)
from django.core.cache import cache
# RETRIEVE ALL
class StateListAPIViewOld(APIView):
    def post(self, request):
        cache_key = "all_states_list"
        cached_data = cache.get(cache_key)
        states = State.objects.filter(flag=True).order_by('state_name')
        serializer = StateSerializer(states, many=True)
        
        response_data = {
            "total": states.count(),
            "data": serializer.data
        }
        
        cache.set(cache_key, response_data, timeout=60)
        
        return Response({
            'msg': 'All states fetched successfully',
            "total": cached_data['total'],
            "data": cached_data['data'],
            'status': 'success',
            'data': serializer.data,
            "response_data": response_data
        }, status=status.HTTP_200_OK)
 
class StateListAPIView(APIView):
    def post(self, request):
        cache_key = "all_states_list"
        
        # 1. Check if the data exists in Redis
        cached_data = cache.get(cache_key)
        
        if cached_data is not None:
            # CACHE HIT: Return the cached data instantly and stop!
            return Response({
                'status': 'success',
                'msg': 'All states fetched successfully (from cache)',
                'total': cached_data['total'],
                'data': cached_data['data']
            }, status=status.HTTP_200_OK)
            
        # 2. CACHE MISS: If not in Redis, do the database work
        states = State.objects.filter(flag=True).order_by('state_name')
        serializer = StateSerializer(states, many=True)
        
        response_data = {
            "total": states.count(),
            "data": serializer.data
        }
        
        # 3. Store it in Redis for 60 seconds
        cache.set(cache_key, response_data, timeout=60)
        
        # 4. Return the freshly fetched data
        return Response({
            'status': 'success',
            'msg': 'All states fetched successfully (from database)',
            'total': response_data['total'],
            'data': response_data['data']
        }, status=status.HTTP_200_OK)

# RETRIEVE SINGLE
class StateDeleteAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('id')
        state_instance = get_object_or_404(State, id=state_id)
        state_instance.flag=False
        state_instance.save()
        # serializer = StateSerializer(state_instance)
        return Response({
            'msg': 'State Deleted successfully',
            'status': 'success',
            
        }, status=status.HTTP_200_OK)
    

# ////////////////////////////////////////////////////////////

from .models import State  # make sure this is imported

class DistrictCreateAPIView(APIView):
    def post(self, request):
        data = request.data

        # List आली असेल तर पहिल्या object मधून state घ्या
        if isinstance(data, list):
            if not data:
                return Response({
                    'msg': 'Empty data',
                    'status': 'error'
                }, status=status.HTTP_400_BAD_REQUEST)

            state_id = data[0].get('state')
        else:
            state_id = data.get('state')

        if not state_id:
            return Response({
                'msg': 'State ID is required',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        if not State.objects.filter(
            id=state_id,
            is_active=True,
            flag=True
        ).exists():
            return Response({
                'msg': 'Invalid state ID or state is inactive',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        serializer = DistrictSerializer(
            data=data,
            many=isinstance(data, list)
        )

        if serializer.is_valid():
            serializer.save()
            return Response({
                'msg': 'District(s) created successfully',
                'status': 'success',
                'data': serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            'msg': 'Validation failed',
            'status': 'error',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)



class DistrictUpdateAPIView(APIView):
    def post(self, request):
        district_id = request.data.get('id')
        if not district_id:
            return Response({
                'msg': 'District ID is required',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        district_instance = get_object_or_404(District, id=district_id)

        # Optional: Validate state ID if provided
        state_id = request.data.get('state')
        if state_id:  # Only validate if it's being updated
            if not State.objects.filter(id=state_id, is_active=True, flag=True).exists():
                return Response({
                    'msg': 'Invalid state ID or state is inactive',
                    'status': 'error'
                }, status=status.HTTP_400_BAD_REQUEST)

        serializer = DistrictSerializer(district_instance, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                'msg': 'District updated successfully',
                'status': 'success',
                'data': serializer.data
            }, status=status.HTTP_200_OK)
        return Response({
            'msg': 'Validation failed',
            'status': 'error',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)



# ///


# RETRIEVE SINGLE
class DistrictRetrieveAPIView(APIView):
    def post(self, request):
        district_id = request.data.get('id')
        district_instance = get_object_or_404(District, id=district_id)
        serializer = DistrictSerializer(district_instance)
        return Response({
            'msg': 'District fetched successfully',
            'status': 'success',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


# RETRIEVE ALL
class DistrictListActiveAPIView(APIView):
    def post(self, request):
        districts = District.objects.filter(is_active=True, flag=True).order_by('district_name')
        serializer = DistrictSerializer(districts, many=True)
        return Response({
            'msg': 'All districts fetched successfully',
            'status': 'success',
            'data': serializer.data
        }, status=status.HTTP_200_OK)

class DistrictListAPIView(APIView):
    def post(self, request):
        districts = District.objects.filter(flag=True).order_by('district_name')
        serializer = DistrictSerializer(districts, many=True)
        return Response({
            'msg': 'All districts fetched successfully',
            'status': 'success',
            'data': serializer.data
        }, status=status.HTTP_200_OK)


# DELETE (SOFT DELETE)
class DistrictDeleteAPIView(APIView):
    def post(self, request):
        district_id = request.data.get('id')
        district_instance = get_object_or_404(District, id=district_id)
        district_instance.flag = False
        district_instance.save()
        return Response({
            'msg': 'District deleted successfully',
            'status': 'success'
        }, status=status.HTTP_200_OK)
    

# Taluka 



# CREATE

class TalukaCreateAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('state')
        district_id = request.data.get('district')
        taluka_names = request.data.get('taluka_name')  # expecting a list

        # Validate required fields
        if not all([state_id, district_id, taluka_names]):
            return Response({'msg': 'State, District, and Taluka names are required', 'status': 'error'}, status=400)

        # Ensure taluka_names is a list
        if isinstance(taluka_names, str):
            # Split by comma if provided as comma-separated string
            taluka_names = [name.strip() for name in taluka_names.split(',') if name.strip()]

        # Validate state and district existence
        if not State.objects.filter(id=state_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid or inactive state ID', 'status': 'error'}, status=400)

        if not District.objects.filter(id=district_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid or inactive district ID', 'status': 'error'}, status=400)

        created_talukas = []
        errors = []

        for name in taluka_names:
            # Check if Taluka already exists in the same district
            if Taluka.objects.filter(taluka_name__iexact=name, district_id=district_id).exists():
                errors.append(f"Taluka '{name}' already exists in this district")
                continue

            serializer = TalukaSerializer(data={
                "taluka_name": name,
                "state": state_id,
                "district": district_id,
                "is_active": request.data.get('is_active', True),
                "flag": request.data.get('flag', True)
            })

            if serializer.is_valid():
                serializer.save()
                created_talukas.append(serializer.data)
            else:
                errors.append({name: serializer.errors})

        return Response({
            'msg': 'Taluka creation completed',
            'status': 'success' if created_talukas else 'error',
            'created': created_talukas,
            'errors': errors
        }, status=201 if created_talukas else 400)


# UPDATE
class TalukaUpdateAPIView(APIView):
    def post(self, request):
        taluka_id = request.data.get('id')
        if not taluka_id:
            return Response({'msg': 'Taluka ID is required', 'status': 'error'}, status=400)

        taluka_instance = get_object_or_404(Taluka, id=taluka_id)

        state_id = request.data.get('state')
        district_id = request.data.get('district')

        if state_id and not State.objects.filter(id=state_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid or inactive state ID', 'status': 'error'}, status=400)

        if district_id and not District.objects.filter(id=district_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid or inactive district ID', 'status': 'error'}, status=400)

        serializer = TalukaSerializer(taluka_instance, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({'msg': 'Taluka updated successfully', 'status': 'success', 'data': serializer.data}, status=200)
        return Response({'msg': 'Validation failed', 'status': 'error', 'errors': serializer.errors}, status=400)


# RETRIEVE SINGLE
class TalukaRetrieveAPIView(APIView):
    def post(self, request):
        taluka_id = request.data.get('id')
        taluka_instance = get_object_or_404(Taluka, id=taluka_id)
        serializer = TalukaSerializer(taluka_instance)
        return Response({'msg': 'Taluka fetched successfully', 'status': 'success', 'data': serializer.data}, status=200)


# RETRIEVE ALL
class TalukaListAPIView(APIView):
    def post(self, request):
        talukas = Taluka.objects.filter(flag=True).order_by('taluka_name')
        serializer = TalukaSerializer(talukas, many=True)
        return Response({'msg': 'All talukas fetched successfully', 'status': 'success', 'data': serializer.data}, status=200)


class TalukaListActiveAPIView(APIView):
    def post(self, request):
        talukas = Taluka.objects.filter(is_active=True, flag=True).order_by('taluka_name')
        serializer = TalukaSerializer(talukas, many=True)
        return Response({'msg': 'All talukas fetched successfully', 'status': 'success', 'data': serializer.data}, status=200)


# DELETE (Soft delete)
class TalukaDeleteAPIView(APIView):
    def post(self, request):
        taluka_id = request.data.get('id')
        taluka_instance = get_object_or_404(Taluka, id=taluka_id)
        taluka_instance.flag = False
        taluka_instance.save()
        return Response({'msg': 'Taluka deleted successfully', 'status': 'success'}, status=200)






#  For Vilages


# Create

# views.py

from .models import Village, State, District, Taluka
from .serializers import VillageSerializer
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status


class VillageCreateAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('state')
        district_id = request.data.get('district')
        taluka_id = request.data.get('taluka')
        villages = request.data.get('villages')

        if not all([state_id, district_id, taluka_id, villages]):
            return Response({
                'msg': 'State, District, Taluka and villages are required',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        if not isinstance(villages, list) or not villages:
            return Response({
                'msg': 'Villages should be a non-empty list',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        village_data = []

        for village in villages:
            village_data.append({
                'village_name': village,
                'state': state_id,
                'district': district_id,
                'taluka': taluka_id
            })

        serializer = VillageSerializer(data=village_data, many=True)

        if serializer.is_valid():
            serializer.save()
            return Response({
                'msg': 'Villages created successfully',
                'status': 'success',
                'data': serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            'msg': 'Validation failed',
            'status': 'error',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
class VillageDeleteAPIView(APIView):
    def delete(self, request):
        state_id = request.data.get('state')
        district_id = request.data.get('district')
        taluka_id = request.data.get('taluka')

        # Validate required fields
        if not all([state_id, district_id, taluka_id]):
            return Response({
                'msg': 'State, District and Taluka are required',
                'status': 'error'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate hierarchy
        if not State.objects.filter(id=state_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid state ID', 'status': 'error'}, status=400)

        if not District.objects.filter(id=district_id, state_id=state_id, is_active=True, flag=True).exists():
            return Response({'msg': 'Invalid district ID', 'status': 'error'}, status=400)

        if not Taluka.objects.filter(
            id=taluka_id,
            state_id=state_id,
            district_id=district_id,
            is_active=True,
            flag=True
        ).exists():
            return Response({'msg': 'Invalid taluka ID', 'status': 'error'}, status=400)

        villages_qs = Village.objects.filter(
            state_id=state_id,
            district_id=district_id,
            taluka_id=taluka_id
        )

        if not villages_qs.exists():
            return Response({
                'msg': 'No villages found for this taluka',
                'status': 'error'
            }, status=status.HTTP_404_NOT_FOUND)

        deleted_count = villages_qs.count()
        villages_qs.delete()

        return Response({
            'msg': f'{deleted_count} villages deleted successfully',
            'status': 'success'
        }, status=status.HTTP_200_OK)




class StateDistrictAPIView(APIView):
    def get(self, request, state_id):
        # Validate if the state exists
        try:
            state = State.objects.get(id=state_id, is_active=True, flag=True)
        except State.DoesNotExist:
            return Response({"msg": "State not found or inactive", "status": "error"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get districts for the given state
        districts = District.objects.filter(state=state, is_active=True, flag=True)
        
        # Serialize districts and return
        serializer = DistrictSerializer(districts, many=True)
        return Response({"msg": "Districts found", "status": "success", "data": serializer.data})
    

class DistrictTalukaAPIView(APIView):
    def get(self, request, district_id):
        # Validate if the district exists
        try:
            district = District.objects.get(id=district_id, is_active=True, flag=True)
        except District.DoesNotExist:
            return Response({"msg": "District not found or inactive", "status": "error"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get talukas for the given district
        talukas = Taluka.objects.filter(district=district, is_active=True, flag=True)
        
        # Serialize talukas and return
        serializer = TalukaSerializer(talukas, many=True)
        return Response({"msg": "Talukas found", "status": "success", "data": serializer.data})


class TalukaVillageAPIView(APIView):
    def get(self, request, taluka_id):
        # Validate if the taluka exists
        try:
            taluka = Taluka.objects.get(id=taluka_id, is_active=True, flag=True)
        except Taluka.DoesNotExist:
            return Response({"msg": "Taluka not found or inactive", "status": "error"}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get villages for the given taluka
        villages = Village.objects.filter(taluka=taluka, is_active=True, flag=True)
        
        # Serialize villages and return
        serializer = VillageSerializer(villages, many=True)
        return Response({"msg": "Villages found", "status": "success", "data": serializer.data})





# class StateListAPIView(APIView):
#     def post(self, request):
#         # Fetch all active and flagged states
#         states = State.objects.filter(is_active=True, flag=True)

#         if not states.exists():
#             return Response({
#                 "msg": "No active states found.",
#                 "status": "error"
#             }, status=status.HTTP_404_NOT_FOUND)

#         # Serialize and return state data
#         serializer = StateSerializer(states, many=True)
#         return Response({
#             "msg": "States found.",
#             "status": "success",
#             "data": serializer.data
#         }, status=status.HTTP_200_OK)



class StateDistrictAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('state_id')

        # Check if state_id is provided
        if not state_id:
            return Response({
                "msg": "State ID is required.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate and fetch the state
        try:
            state = State.objects.get(id=state_id, is_active=True, flag=True)
        except State.DoesNotExist:
            return Response({
                "msg": "State not found or inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Fetch districts under this state
        districts = District.objects.filter(state=state, is_active=True, flag=True)

        # Return serialized data
        serializer = DistrictSerializer(districts, many=True)
        return Response({
            "msg": "Districts found.",
            "status": "success",
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    

class DistrictTalukaAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('state_id')
        district_id = request.data.get('district_id')

        # Validate input presence
        if not state_id or not district_id:
            return Response({
                "msg": "Both state_id and district_id are required.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate state existence
        try:
            state = State.objects.get(id=state_id, is_active=True, flag=True)
        except State.DoesNotExist:
            return Response({
                "msg": "State not found or inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate district existence and belonging to the given state
        try:
            district = District.objects.get(id=district_id, state_id=state_id, is_active=True, flag=True)
        except District.DoesNotExist:
            return Response({
                "msg": "District not found under the provided state or it is inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Fetch talukas
        talukas = Taluka.objects.filter(state=state, district=district, is_active=True, flag=True)

        # Check if any talukas exist
        if not talukas.exists():
            return Response({
                "msg": "No talukas found for the given state and district.",
                "status": "success",
                "data": []
            }, status=status.HTTP_200_OK)

        # Serialize and return
        serializer = TalukaSerializer(talukas, many=True)
        return Response({
            "msg": "Talukas found.",
            "status": "success",
            "data": serializer.data
        }, status=status.HTTP_200_OK)




class TalukaVillageAPIView(APIView):
    def post(self, request):
        state_id = request.data.get('state_id')
        district_id = request.data.get('district_id')
        taluka_id = request.data.get('taluka_id')

        # Check for missing fields
        if not all([state_id, district_id, taluka_id]):
            return Response({
                "msg": "State ID, District ID, and Taluka ID are required.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate state
        try:
            state = State.objects.get(id=state_id, is_active=True, flag=True)
        except State.DoesNotExist:
            return Response({
                "msg": "State not found or inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate district and match with state
        try:
            district = District.objects.get(id=district_id, state=state, is_active=True, flag=True)
        except District.DoesNotExist:
            return Response({
                "msg": "District not found under the provided state or it is inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate taluka and match with district and state
        try:
            taluka = Taluka.objects.get(id=taluka_id, district=district, state=state, is_active=True, flag=True)
        except Taluka.DoesNotExist:
            return Response({
                "msg": "Taluka not found under the given district and state or it is inactive.",
                "status": "error"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get villages
        villages = Village.objects.filter(taluka=taluka, district=district, state=state, is_active=True, flag=True)

        # Return serialized data
        serializer = VillageSerializer(villages, many=True)
        return Response({
            "msg": "Villages found.",
            "status": "success",
            "data": serializer.data
        }, status=status.HTTP_200_OK)