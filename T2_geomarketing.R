library(RPostgreSQL)
library(dplyr)
library(ggplot2)
library(GGally)
library(plyr)
library(rakeR)
library(data.table)
library(geojsonio)
library(rgdal)


#--------------------------------conectar con base de datos y extraer información necesaria------------------------------------#

#------Extracción de encuesta CASEN-----#

# Spatial microsimulation Chile

#Conectar con dbpsql
#clave de acceso
pw = {
  "admin"
}
drv = dbDriver("PostgreSQL")

#Crear conexión a base de datos
con = dbConnect(drv, dbname = "postgres",
                host = "localhost", port = 5432,
                user = "postgres", password = "admin")

#Solicitud SQL data "general"
q = "SELECT id_vivienda, region, provincia, comuna, edad, esc, e6a, sexo, oficio4, pco1, y26_1a, y26_1b FROM public.casen WHERE provincia = '131' OR comuna = '13201' OR comuna = '13401';"
data_casen = dbSendQuery(con, q)
data_casen = dbFetch(data_casen)
casen_gs = data_casen
#> ID=c(1:35357)
#casen_gs$ID=ID
#names(casen_gs)



#------Extracción de Censo 2017-----#

#Conectar con dbpSQL
#clave de acceso
pw = {
  "admin"
}
drv = dbDriver("PostgreSQL")

#Crear conexión a base de datos
con = dbConnect(drv, dbname = "postgres",
                host = "localhost", port = 5432,
                user = "postgres", password = "admin")

#Solicitud SQL data "general"
q = "SELECT region, provincia, comuna, dc, area, zc_loc, P08, P09, P15 FROM public.censo WHERE provincia = '131' OR comuna = '13201' OR comuna = '13401';"
data_censo = dbSendQuery(con, q)
data_censo = dbFetch(data_censo)
censo_gs = data_censo





#-------------------------------------------Fin de extraccion de datos--------------------------------------------------#



#-------------------------------------------Preprocesamiento de datos---------------------------------------------------#


                                     #-----------Encuesta Casen------------#


#Agregar datos faltantes para esc con regresion lineal x mínimos cuadrados.
index_esc_na = which(is.na(as.numeric(casen_gs$esc)==T))
casen_2 = casen_gs
casen_2$esc = as.numeric(casen_gs$esc)
casen_2$e6a = as.numeric(casen_gs$e6a)
edu_lm = lm(esc~e6a,casen_2[-index_esc_na,])
edu_pred = predict.lm(edu_lm, casen_2[index_esc_na,])
casen_2$esc[index_esc_na]= round(edu_pred)

#Clasificación por rango de edad
casen_2$edad = as.numeric(casen_2$edad) 
index_menos_60 = which(casen_2$edad<60)
index_mas_60 = which(casen_2$edad>=60)
casen_2$edad_f = NA
casen_2$edad_f[index_menos_60] = "edad_menor_60"
casen_2$edad_f[index_mas_60] = "edad_mayor_60"


#Clasificación por rango de escolaridad
casen_2$esc = as.numeric(casen_2$esc)
index_0 = which(casen_2$esc==0)
index_1_8 = which(casen_2$esc>0 & casen_2$esc<=8)
index_8_12 = which(casen_2$esc>8 & casen_2$esc<=12)
index_mas_12 = which(casen_2$esc>12)
casen_2$esc_f = NA
casen_2$esc_f[index_0] = "esc_0"
casen_2$esc_f[index_1_8] = "esc_1_8"
casen_2$esc_f[index_8_12] = "esc_8_12"
casen_2$esc_f[index_mas_12] = "esc_mas_12"

#Clasificacion por sexo
index_mujer = which(casen_2$sexo==2)
casen_2$sex_f = NA
casen_2$sex_f[index_mujer]="sex_f"
casen_2$sex_f[-index_mujer]="sex_m"

#Clasificacion si recibe ayuda de pensión solidaria
index_pension_sol = which(casen_2$y26_1a==1 | casen_2$y26_1b==1)
casen_2$ayuda = NA
casen_2$ayuda[index_pension_sol] = 1
casen_2$ayuda[-index_pension_sol] = 2

casen_f = data.frame("comuna" = casen_2$comuna,
                     "esc_f" = as.character(casen_2$esc_f),
                     "edad_f" = as.character(casen_2$edad_f),
                     "sexo_f" = as.character(casen_2$sex_f),
                     "ayuda" = as.character(casen_2$ayuda))

casen_f_comunas = dlply(casen_f,.(comuna))


                                #-----------Censo 2017------------#


censo_2 = censo_gs

censo_2$geocode = paste0(censo_2$comuna,censo_2$dc,censo_2$area,censo_2$zc_loc)
names(censo_2)[names(censo_2) == "p08"] <- "sexo"
names(censo_2)[names(censo_2) == "p09"] <- "edad"
names(censo_2)[names(censo_2) == "p15"] <- "esc"



censo_2$edad = as.numeric(censo_2$edad)
edad_menos_60 = aggregate (edad ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a<60))})
edad_mas_60 = aggregate (edad ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a>=60))})
names(edad_menos_60)[names(edad_menos_60) == "edad"] <- "edad_menor_60"
names(edad_mas_60)[names(edad_mas_60) == "edad"] <- "edad_mayor_60"


sexo_mas = aggregate(sexo ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a==1))})
sexo_fem = aggregate(sexo ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a==2))})
names(sexo_mas)[names(sexo_mas) == "sexo"] <- "sex_m"
names(sexo_fem)[names(sexo_fem) == "sexo"] <- "sex_f"

censo_2$esc = as.numeric(censo_2$esc)
esc_0 = aggregate (esc ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a>=0 & a<=3))})
esc_1_8 = aggregate (esc ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a>=4 & a<=6))})
esc_8_12 = aggregate(esc ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a>=7 & a<=10))})
esc_mas_12 = aggregate (esc ~ geocode + comuna, data = censo_2, FUN = function (a) {length(which(a>10))})
names(esc_0)[names(esc_0) == "esc"] <- "esc_0"
names(esc_1_8)[names(esc_1_8) == "esc"] <- "esc_1_8"
names(esc_8_12)[names(esc_8_12) == "esc"] <- "esc_8_12"
names(esc_mas_12)[names(esc_mas_12) == "esc"] <- "esc_mas_12"



tabla_consolidada = Reduce(function(x,y) merge(x = x, y = y, by = "geocode"), list(edad_menos_60, edad_mas_60, sexo_mas, sexo_fem, esc_0, esc_1_8, esc_8_12, esc_mas_12))
tabla_consolidada = tabla_consolidada[,c(1,3,5,7,9,11,13,15,17,16)]
names(tabla_consolidada)[names(tabla_consolidada) == "comuna.y"] <- "comuna"

for (i in 2:9){
  tabla_consolidada[i] = as.numeric(tabla_consolidada[,i])
}


censo_f_comunas = dlply(tabla_consolidada,.(comuna))




#----------------------------------------- Microsimulacion ---------------------------------------------#



vars = c("edad_f","esc_f","sexo_f")

sim_list = list()
for (i in 1:34){
  casen_f_comunas[[i]]$esc_f = as.character(casen_f_comunas[[i]]$esc_f)
  casen_f_comunas[[i]]$edad_f = as.character(casen_f_comunas[[i]]$edad_f)
  casen_f_comunas[[i]]$sexo_f = as.character(casen_f_comunas[[i]]$sexo_f)
  casen_f_comunas[[i]]$zone = as.character(seq.int(nrow(casen_f_comunas[[i]])))
  casen_f_comunas[[i]] = casen_f_comunas[[i]][,c(1,6,3,2,4,5)]
  censo_f_comunas[[i]] = censo_f_comunas[[i]][,c(1,3,2,6,7,8,9,5,4,10)]
  pesos = weight(cons = censo_f_comunas[[i]][,-10], inds = casen_f_comunas[[i]][,-1], vars=vars)
  pesos_int = integerise(pesos, inds = casen_f_comunas[[i]][,-1])
  names(pesos_int)[1]="geocode"
  sim_list[[i]]=pesos_int
}


sim_df = rbindlist(sim_list)
names(sim_df)[1]="GEOCODIGO"
#--------------------------------------Representación------------------------------------------------#

ayuda_count = aggregate(ayuda ~ GEOCODIGO, data = sim_df, FUN = function(a) {length(which(a==1))})

gs_layer <- rgdal::readOGR("C:/Users/ppsa_/Documents/Drope/u/Nivel 10/Geomarketing/T2/zonas_cens_gs/zonas_gs.geojson")
plot(gs_layer)

gs_layer@data = join(gs_layer@data,ayuda_count, by="GEOCODIGO")
plot(gs_layer[,'ayuda'])
