Scriptname ToxiRandContainerScript extends ReferenceAlias  

ToxiRandQuestScript Property QuestScript auto
MiscObject Property ConfirmationItem auto

int itemsPTR
int questItemsPTR
ObjectReference selfRef

Event OnInit()
    selfRef = self.GetReference()
    RegisterForMenu("BarterMenu")

    if(!TryInit())
        return
    else
        ; Debug.Trace("self: " + self + " selfRef: " + selfRef + " items: " + selfRef.GetNumItems())
        if(selfRef.GetNumItems() > 0)
            Bool playerOwnsRef = selfRef.GetActorOwner() == Game.GetPlayer().GetActorBase()
            if(playerOwnsRef == 1)
                JValue.release(itemsPTR)
                JValue.release(questItemsPTR)
                JArray.eraseInteger(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID())
                return
            elseif(JArray.findInt(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID()) >= 0)
                return
            else
                RandomizeCheckAndStart(selfRef)
            endif
        endif
    endif
EndEvent

Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akSourceContainer)
    if(selfRef)
        if(selfRef.GetContainerForms().Find(ConfirmationItem) < 0)
            selfRef.AddItem(ConfirmationItem)
        endif
    endif
EndEvent

bool Function TryInit()
    int i = 5 ;; Amount of tries to get reference before quitting
    while(self && !selfRef && i > 0)
        Utility.Wait(0.5)
        selfRef = self.GetReference()
        i -= 1
    endwhile
    return selfRef != None
EndFunction

;; Preps container for randomization, returns true if it needs to be randomized
;; Assumes you will randomize it directly after this call
bool Function ContainerReadyForRandomize(ObjectReference akContainer)
    ;; Check for confirmation item, meaning we've randomized this container already
    return akContainer.GetContainerForms().Find(ConfirmationItem) < 0
EndFunction

Function RandomizeCheckAndStart(ObjectReference akContainer)
    RegisterForSingleUpdate(30)
    Bool playerOwnsRef = selfRef.GetActorOwner() == Game.GetPlayer().GetActorBase()
    if(playerOwnsRef == 1)
        JValue.release(itemsPTR)
        JValue.release(questItemsPTR)
        JArray.eraseInteger(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID())
        return
    elseif(ContainerReadyForRandomize(akContainer))
        JArray.addInt(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID())
        RandomizeAllItems(akContainer)
    endif

EndFunction

Event OnUpdate()
    ;; Cleanup if something went wrong while randomizing
    JValue.release(itemsPTR)
    JValue.release(questItemsPTR)
    JArray.eraseInteger(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID())
EndEvent

Event OnMenuOpen(string menuName)
    if(selfRef)
        Debug.Notification("Checking for shop randomization")
        RandomizeCheckAndStart(selfRef)
    endif
EndEvent

Function RandomizeAllItems(ObjectReference akContainer)
    
    akContainer.AddItem(ConfirmationItem) ;; Add item so we know it's been randomized

    itemsPTR = JArray.objectWithForms(PO3_SKSEFunctions.AddAllItemsToArray(akContainer, false, false, true))
    questItemsPTR = JArray.objectWithForms(PO3_SKSEFunctions.GetQuestItems(akContainer))
    
    JValue.retain(itemsPTR, "ToxiRand")
    JValue.retain(questItemsPTR, "ToxiRand")

    if(JArray.count(itemsPTR) > 0)
        if(QuestScript.useShaderFX)
            QuestScript.OnRandomizeEffect.Play(akContainer)
        endif
        RandomizeItemRecursive(akContainer, JArray.count(itemsPTR) - 1)
        QuestScript.TryUpdateBarterMenu()
    endif

    JArray.eraseInteger(QuestScript.currentlyRandomizingContainersPTR, selfRef.GetFormID())
    JValue.release(itemsPTR)
    JValue.release(questItemsPTR)
    UnregisterForUpdate()
    QuestScript.OnRandomizeEffect.Stop(akContainer)
EndFunction

;; Recursive loop
;; While loops seem to be unable to start while barter menu is open
Function RandomizeItemRecursive(ObjectReference akContainer, int index)
    RandomizeItemAt(akContainer, index)
    if(index > 0)
        RandomizeItemRecursive(akContainer, index - 1)
    endif
EndFunction

;; Get random piece of armor recursively
;; If no enchant setting, keep randomizing until no enchant
Form Function GetRandomArmorRecursive(int offset, int tries, bool getEnchanted = false)
    
    if(!QuestScript.changeEnchantmentRateContainer || tries <= 0)
        return QuestScript.RandomFormFromArray(QuestScript.allArmor, QuestScript.currentseed, offset)
    endif

    Armor armr = QuestScript.RandomFormFromArray(QuestScript.allArmor, QuestScript.currentseed, offset) as Armor

    if(((armr.GetEnchantment() == None && getEnchanted) || (armr.GetEnchantment() != None && !getEnchanted)))
        return GetRandomArmorRecursive(offset + ToxiExtensions.Noise1D(offset, QuestScript.currentseed), tries - 1)
    endif

    return armr
EndFunction

;; Get random weapon recursively
;; If no enchant setting, keep randomizing until no enchant
Form Function GetRandomWeaponRecursive(int offset, int tries, bool getEnchanted = false)
    if(!QuestScript.changeEnchantmentRateContainer || tries <= 0)
        return QuestScript.RandomFormFromArray(QuestScript.allWeapons, QuestScript.currentseed, offset)
    endif

    Weapon wpn = QuestScript.RandomFormFromArray(QuestScript.allWeapons, QuestScript.currentseed, offset) as Weapon

    if(((wpn.GetEnchantment() == None && getEnchanted) || (wpn.GetEnchantment() != None && !getEnchanted)))
        return GetRandomWeaponRecursive(offset + ToxiExtensions.Noise1D(offset, QuestScript.currentseed), tries - 1)
    endif

    return wpn
EndFunction

;; Randomize item at container index
Function RandomizeItemAt(ObjectReference akContainer, int index)
    Form item = JArray.getForm(itemsPTR, index)

    if(!item)
        return
    elseif(item.GetFormID() == akContainer.GetFormID())
        ;; Containers seem to store themselves as an item?
        ;; It's weird. Skip it.
        return
    endif

    int itemcount = akContainer.GetItemCount(item)
    int offset = item.GetFormID()

    if(QuestScript.offsetContainerItemsByContainerID)
        offset += ToxiExtensions.Noise1D(akContainer.GetFormID(), QuestScript.currentseed)
    endif

    if(QuestScript.offsetContainerItemsByCellID)
        offset += ToxiExtensions.Noise1D(akContainer.GetParentCell().GetFormID(), QuestScript.currentseed)
    endif

    if(item.GetFormID() == ConfirmationItem.GetFormID()) 
        ;; This is how we know we've randomized
        return
    elseif(item.GetFormID() == 0xF) ;;Gold
        return
    elseif(JArray.findForm(questItemsPTR, item) >= 0)
        return
    elseif(item.GetType() == ToxiRandFormType.kArmor())
        if(QuestScript.containerRandomizeArmor)
            bool getEnchanted = ToxiExtensions.GetChanceResult(QuestScript.changeEnchantmentChance, QuestScript.currentseed, offset)
            item = GetRandomArmorRecursive(offset, 1000, getEnchanted)
        endif
    elseif(item.GetType() == ToxiRandFormType.kWeapon())
        if(QuestScript.containerRandomizeWeapons)
            bool getEnchanted = ToxiExtensions.GetChanceResult(QuestScript.changeEnchantmentChance, QuestScript.currentseed, offset)
            item = GetRandomWeaponRecursive(offset, 1000, getEnchanted)
        endif
    elseif(item.GetType() == ToxiRandFormType.kMisc())
        if(QuestScript.containerRandomizeMisc)
            item = QuestScript.RandomFormFromArray(QuestScript.allMisc, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kBook())
        if(QuestScript.containerRandomizeBooks)
            item = QuestScript.RandomFormFromArray(QuestScript.allBooks, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kPotion())
        if(QuestScript.containerRandomizePotions)
            item = QuestScript.RandomFormFromArray(QuestScript.allPotions, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kKey())
        if(QuestScript.containerRandomizeKeys)
            item = QuestScript.RandomFormFromArray(QuestScript.allKeys, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kScrollItem())
        if(QuestScript.containerRandomizeScrolls)
            item = QuestScript.RandomFormFromArray(QuestScript.allScrolls, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kIngredient())
        if(QuestScript.containerRandomizeIngredients)
            item = QuestScript.RandomFormFromArray(QuestScript.allIngredients, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kAmmo())
        if(QuestScript.containerRandomizeAmmo)
            item = QuestScript.RandomFormFromArray(QuestScript.allAmmo, QuestScript.currentseed, offset)
        endif
    elseif(item.GetType() == ToxiRandFormType.kSoulGem())
        if(QuestScript.containerRandomizeSoulGems)
            item = QuestScript.RandomFormFromArray(QuestScript.allSoulGems, QuestScript.currentseed, offset)
        endif
    endif

    ;; If container is being referenced by more than
    ;; this alias, it might be a quest item
    ;; Don't remove item, but do add a new item
    if(akContainer.GetNumReferenceAliases() <= 1)
        ;; Individual item removal because 
        ;; RemoveAllItems() was deleting quest items (for no good reason)
        akContainer.RemoveItem(JArray.getForm(itemsPTR, index), itemcount)
    endif

    akContainer.AddItem(item, itemcount)
EndFunction
