# RouterOS script: Failover and Recovery
# Copyright Grzegorz Kowalik <kontakt@grzegorzkowalik.com>
#
#Skrypt realizujacy usluge Failover miedzy dwoma operatorami ISP
#INFO: Musialem zmienne dodac w funkcjach, poniewaz nie dokonca zmienna :globla chciala dzialac
#INFO: Testowane na wersji ROS 7.12.1
#INFO: Oznacz komentarzem domyslne trasy routingu. WAN1 jako podstaowowa trasa, WAN2 jako zapas.

#Funkcja sprawdza czy jest Internet przez glowny interfejs
:local checkConnections do={
    :local failCount 0
    :local checkHost 8.8.8.8
    :local primaryInterface ether1
    :local failThreshold 10

    :for i from=1 to=$failThreshold do={
        :if ([/ping $checkHost interface=$primaryInterface count=1] = 0) do={
        :set failCount ($failCount + 1)
        }
    }
    :return  $failCount
}

#Sprawdzamy czy FailOver jest aktywny, i czy dziala zapasowe lacze, 
:global checkFailoverStatus do={
    :local failOverStatus    
    :if ([/ip route get [find where comment="WAN1"] disabled]=true  && [/ip route get [find where comment="WAN2"] disabled]=false) do={
        #Zapasowe lacze aktywne
        :set failOverStatus 1
        :return $failOverStatus
    } else={
        :set failOverStatus 0
        :return $failOverStatus
        }
}

#funkcja odpowiedzialna za przelaczenie routingu na zapasowy Interfejs LTE
:global makeFailover do={
    :local secondaryInterface lte1
    :local primaryInterface ether1
    
    :log warning "Failover: Zmiana interfejsu na $secondaryInterface"
    /ip route set [/ip route find where comment="WAN1"] disabled=yes
    /ip route set [/ip route find where comment="WAN2"] disable=no
    /tool e-mail send to="adres_email@domena.pl" subject="Failover do $secondaryInterface" body="Failover do $secondaryInterface zostal aktywowany"
}

#Przywaracnie routingu na glowny WAN
:global recoveryPrimaryWAN do={
    /ip route set [/ip route find where comment="WAN1"] disable=no
    /ip route set [/ip route find where comment="WAN2"] disabled=yes
    :log warning "Failover Recovery: Przywrocono glowne lacze - WAN1"
    /tool e-mail send to="adres_email@domena.pl" subject="Failover Recovery: Przywrocono WAN1" body="Recovery: podstawowowe lacze WAN1 zostalo przywrocone" 

}

#glowne wywolanie skryptu, sprawdza ilosc odpowiedzi z funcji checkConnection, jezeli na 10 pingow mamy 7 timeoutow przechodzi do realizacji Failovera
#dodatkowo weryfikuje na jakim WANie obecnie pracuje urzadzenie, aby nie zapetlic sie w powiadomieniach i przelaczaniu routingu
:if ([$checkFailoverStatus]=0) do={
    :if ([$checkConnections] >= 7) do={
        $makeFailover
        }
}
:if ([$checkFailoverStatus]=1) do={
    :if ([$checkConnections] = 0) do={
        $recoveryPrimaryWAN
        }
}
