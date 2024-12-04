# **LFRTools Addon**

**LFRTools** is a World of Warcraft addon designed to improve accountability in Looking for Raid (LFR) and Looking for Group (LFG). It automatically checks if players’ specializations match the roles they signed up for and announces discrepancies.

This addon is particularly useful for identifying players who join as Healers or Tanks but do not fulfill their assigned roles, allowing the group to address such behavior effectively.

---

## **Features**
- **Automatic Role Check**: When a player joins an LFR or LFG, the addon compares their specialization to the role they signed up for.
- **Announcement Options**: Violations can be announced to the party or displayed privately to you.
- **Manual Scan**: Run a manual check of all group members' roles with a single command.

---

## **In-Game Commands**
- `/lfrtools`: Opens the addon’s settings panel.
- `/lfrtools checklfr`: Quickly checks if the current instance is an LFR.

---

## **Manual Scan**
To initiate a manual scan, run the following macro in-game:

```plaintext
/run LFRtools.scanGroup()


## **Settings**

### **Enabled**
- **Checked**: Enables role checking.
- **Unchecked**: Disables all role-checking functionality.

### **Announce Detection to Party**
- **Checked**: Violations will be announced in party or raid chat for everyone to see.
- **Unchecked**: Violations will only be displayed to you privately.